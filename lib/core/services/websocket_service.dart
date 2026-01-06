import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../constants/connection_state.dart' as app;
import '../constants/message_types.dart';
import '../models/clipboard_item.dart';
import '../utils/logger.dart';

/// WebSocket service for communication with desktop hub
class WebSocketService {
  WebSocketService._();
  static final WebSocketService instance = WebSocketService._();

  // WebSocket connection
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  // State
  app.ConnectionState _connectionState = app.ConnectionState.disconnected;
  String? _hubEndpoint;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  DateTime? _lastPongTime;

  // Configuration
  static const int maxReconnectAttempts = 5;
  static const Duration pingInterval = Duration(seconds: 30);
  static const Duration pongTimeout = Duration(seconds: 10);
  static const Duration initialReconnectDelay = Duration(seconds: 1);

  // Stream controllers
  final _connectionStateController =
      StreamController<app.ConnectionState>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _clipController = StreamController<ClipboardItem>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Getters
  app.ConnectionState get connectionState => _connectionState;
  Stream<app.ConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<ClipboardItem> get clipStream => _clipController.stream;
  Stream<String> get errorStream => _errorController.stream;
  bool get isConnected => _connectionState == app.ConnectionState.connected;
  String? get currentEndpoint => _hubEndpoint;

  /// Connect to hub
  Future<bool> connect(String endpoint) async {
    if (_connectionState == app.ConnectionState.connecting) {
      AppLogger.warning('Already connecting, ignoring duplicate request');
      return false;
    }

    _hubEndpoint = endpoint;
    _reconnectAttempts = 0;
    return await _doConnect();
  }

  Future<bool> _doConnect() async {
    if (_hubEndpoint == null) return false;

    _setConnectionState(app.ConnectionState.connecting);
    AppLogger.info('Connecting to $_hubEndpoint');

    try {
      // Create WebSocket connection
      final uri = Uri.parse(_hubEndpoint!);
      _channel = WebSocketChannel.connect(uri);

      // Wait for connection to be ready with timeout
      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timed out');
        },
      );

      // Setup message listener
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: false,
      );

      _setConnectionState(app.ConnectionState.connected);
      _reconnectAttempts = 0;
      _startPingTimer();

      AppLogger.info('Connected to $_hubEndpoint');
      return true;
    } catch (e) {
      AppLogger.error('Connection failed', error: e);
      _setConnectionState(app.ConnectionState.error);
      _errorController.add('Connection failed: ${e.toString()}');
      _scheduleReconnect();
      return false;
    }
  }

  /// Disconnect from hub
  Future<void> disconnect() async {
    AppLogger.info('Disconnecting from hub');
    _cancelTimers();
    _reconnectAttempts = maxReconnectAttempts; // Prevent auto-reconnect

    try {
      await _subscription?.cancel();
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (e) {
      AppLogger.error('Error during disconnect', error: e);
    }

    _channel = null;
    _subscription = null;
    _setConnectionState(app.ConnectionState.disconnected);
  }

  /// Reconnect to last known hub
  Future<bool> reconnect() async {
    if (_hubEndpoint == null) {
      AppLogger.warning('No endpoint to reconnect to');
      return false;
    }
    _reconnectAttempts = 0;
    return await _doConnect();
  }

  /// Send raw message to hub
  Future<void> sendRaw(String message) async {
    if (!isConnected || _channel == null) {
      throw Exception('Not connected to hub');
    }

    AppLogger.ws(message, isIncoming: false);
    _channel!.sink.add(message);
  }

  /// Send typed message to hub
  Future<void> send(MessageType type, Map<String, dynamic> payload) async {
    final message = {'type': type.value, ...payload};
    await sendRaw(jsonEncode(message));
  }

  /// Send encrypted CLIP_PUSH message
  Future<void> sendClipPush({
    required String encryptedPayload,
    required String iv,
    required String deviceName,
    String? battery,
  }) async {
    await send(MessageType.clipPush, {
      'payload_encrypted': encryptedPayload,
      'iv': iv,
      'device_info': {'name': deviceName, 'battery': battery},
    });
  }

  /// Send PAIRING_REQUEST message
  Future<void> sendPairingRequest({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String pairingToken,
  }) async {
    await send(MessageType.pairingRequest, {
      'device_id': deviceId,
      'device_name': deviceName,
      'platform': platform,
      'pairing_token': pairingToken,
    });
  }

  /// Send HANDSHAKE message (required to identify device after connect)
  Future<void> sendHandshake({required String deviceId}) async {
    await send(MessageType.handshake, {'device_id': deviceId});
  }

  /// Send GET_LATEST request
  Future<void> sendGetLatest() async {
    await send(MessageType.getLatest, {});
  }

  /// Send PONG response
  Future<void> sendPong() async {
    await send(MessageType.pong, {});
  }

  void _handleMessage(dynamic rawMessage) {
    final message = rawMessage.toString();
    AppLogger.ws(message, isIncoming: true);
    AppLogger.info('📨 WebSocketService raw message length: ${message.length}');

    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      AppLogger.info(
        '📦 Decoded JSON, type: ${data['type']}, keys: ${data.keys.toList()}',
      );

      // Add message to stream ONCE here - remove duplicates in switch case
      _messageController.add(data);

      final typeStr = data['type'] as String?;
      if (typeStr == null) {
        AppLogger.warning('Message has no type');
        return;
      }

      final type = MessageType.fromString(typeStr);
      AppLogger.info('🔍 MessageType enum: ${type?.value ?? "null"}');

      switch (type) {
        case MessageType.clipBroadcast:
        case MessageType.encrypted:
          // Encrypted clip broadcast - already forwarded to SyncService via global add
          AppLogger.info(
            '✉️ Clip broadcast/encrypted - forwarding to SyncService (streams are active)',
          );
          // REMOVED DUPLICATE ADD
          break;

        case MessageType.ping:
          AppLogger.info('🏓 Ping received, sending PONG');
          sendPong();
          break;

        case MessageType.pairingResponse:
          // Handle pairing response - forward to ConnectionManager
          AppLogger.info(
            '🤝 Pairing response received: success=${data['success']}',
          );
          // Already forwarded via _messageController.add(data)
          break;

        case MessageType.handshakeResponse:
          // Handle handshake response - forward to ConnectionManager
          final success = data['success'] == true;
          AppLogger.info('🤝 Handshake response received: success=$success');
          if (!success) {
            final error = data['error'] ?? 'Unknown handshake error';
            AppLogger.error('Handshake failed: $error');
            _errorController.add('Handshake failed: $error');
          }
          // Already forwarded via _messageController.add(data)
          break;

        case MessageType.pong:
          // Track last pong time for connection health monitoring
          _lastPongTime = DateTime.now();
          AppLogger.info('🏓 Pong received');
          break;

        case MessageType.error:
          final errorMsg = data['message'] ?? 'Unknown error';
          AppLogger.error('❌ Server error: $errorMsg');
          _errorController.add(errorMsg);
          break;

        default:
          AppLogger.info('ℹ️ Unhandled message type: ${type?.value}');
          break;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to parse message', error: e);
      print('Parse error stack trace: $stackTrace');
    }
  }

  void _handleError(dynamic error) {
    AppLogger.error('WebSocket error', error: error);
    _errorController.add(error.toString());
    _setConnectionState(app.ConnectionState.error);
    _scheduleReconnect();
  }

  void _handleDone() {
    AppLogger.info('WebSocket connection closed');
    _cancelTimers();

    if (_connectionState != app.ConnectionState.disconnected) {
      _setConnectionState(app.ConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      AppLogger.warning('Max reconnect attempts reached');
      _setConnectionState(app.ConnectionState.error);
      return;
    }

    _reconnectAttempts++;
    final delay =
        initialReconnectDelay *
        (1 << (_reconnectAttempts - 1)); // Exponential backoff
    AppLogger.info(
      'Scheduling reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_connectionState != app.ConnectionState.connected) {
        _doConnect();
      }
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (_) {
      if (isConnected) {
        // Check if we received pong recently
        if (_lastPongTime != null) {
          final elapsed = DateTime.now().difference(_lastPongTime!);
          if (elapsed > pongTimeout) {
            AppLogger.warning('Pong timeout, reconnecting');
            _handleDone();
            return;
          }
        }
      }
    });
  }

  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _setConnectionState(app.ConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _connectionStateController.add(state);
      AppLogger.info('Connection state: ${state.displayName}');
    }
  }

  /// Reset reconnect attempts (call after manual reconnect succeeds)
  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _messageController.close();
    _clipController.close();
    _errorController.close();
  }
}
