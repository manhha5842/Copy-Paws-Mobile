import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../constants/connection_state.dart' as app;
import '../models/hub_info.dart';
import '../utils/logger.dart';
import 'websocket_service.dart';
import 'storage_service.dart';
import 'encryption_service.dart';
import 'discovery_service.dart';

/// Connection manager that orchestrates the connection flow
class ConnectionManager {
  ConnectionManager._();
  static final ConnectionManager instance = ConnectionManager._();

  // Services
  final _wsService = WebSocketService.instance;
  final _storageService = StorageService.instance;
  final _encryptionService = EncryptionService.instance;
  final _discoveryService = DiscoveryService.instance;

  // State
  HubInfo? _currentHub;
  String? _deviceId;
  String? _deviceName;
  bool _isPaired = false;

  // Stream controllers
  final _connectionStateController =
      StreamController<app.ConnectionState>.broadcast();
  final _hubChangedController = StreamController<HubInfo?>.broadcast();

  // Getters
  app.ConnectionState get connectionState => _wsService.connectionState;
  Stream<app.ConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<HubInfo?> get hubChangedStream => _hubChangedController.stream;
  HubInfo? get currentHub => _currentHub;
  bool get isConnected => _wsService.isConnected;
  bool get isPaired => _isPaired;
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;

  /// Initialize connection manager
  Future<void> initialize() async {
    AppLogger.info('Initializing connection manager');

    // Initialize storage first
    await _storageService.initialize();

    // Load or generate device ID
    _deviceId = _storageService.getDeviceId();
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await _storageService.saveDeviceId(_deviceId!);
      AppLogger.info('Generated new device ID: $_deviceId');
    }

    // Load or generate device name
    _deviceName = _storageService.getDeviceName();
    if (_deviceName == null) {
      _deviceName = await _getDefaultDeviceName();
      await _storageService.saveDeviceName(_deviceName!);
    }

    // Load saved hub info
    _currentHub = _storageService.getHubInfo();
    if (_currentHub != null) {
      AppLogger.info('Loaded saved hub: ${_currentHub!.name}');
      _isPaired = true;

      // Load encryption key - use base64 directly, don't hash
      final secret = await _storageService.getSharedSecret();
      if (secret != null) {
        _encryptionService.setKeyFromBase64(secret);
        AppLogger.info('Loaded encryption key from saved secret');
      }
    }

    // Forward WebSocket connection state
    _wsService.connectionStateStream.listen((state) {
      _connectionStateController.add(state);
    });
  }

  /// Auto-connect to saved hub if available
  Future<bool> autoConnect() async {
    if (_currentHub == null || !_storageService.autoConnect) {
      return false;
    }

    if (!_encryptionService.hasKey) {
      AppLogger.warning('Cannot auto-connect: encryption key not set');
      return false;
    }

    AppLogger.info(
      'Auto-connecting to ${_currentHub!.name} (${_currentHub!.endpoint})',
    );

    // 1. Try direct connection first (fastest)
    if (await connect(_currentHub!)) {
      return true;
    }

    AppLogger.info(
      'Direct connection failed. Starting discovery for hub ID: ${_currentHub!.id}',
    );

    // 2. If direct fails, try discovery to find new IP
    try {
      await _discoveryService.startDiscovery();

      // Wait for matching hub (5 seconds timeout)
      final matchingHub = await _discoveryService.hubsStream
          .expand((hubs) => hubs)
          .firstWhere((hub) => hub.id == _currentHub!.id)
          .timeout(const Duration(seconds: 5));

      AppLogger.info('Found hub via discovery: ${matchingHub.endpoint}');

      // Stop discovery before connecting
      await _discoveryService.stopDiscovery();

      // Connect to the discovered hub
      // Note: We maintain the original secret/pairing status
      return await connect(matchingHub);
    } catch (e) {
      AppLogger.warning('Auto-connect via discovery failed: $e');
      await _discoveryService.stopDiscovery(); // Ensure stopped
      return false;
    }
  }

  /// Connect to a hub
  Future<bool> connect(HubInfo hub) async {
    _currentHub = hub;
    _hubChangedController.add(hub);

    final success = await _wsService.connect(hub.endpoint);

    if (success) {
      AppLogger.info('Connected to hub. Is paired: $_isPaired');

      // If already paired, send HANDSHAKE to identify device
      if (_isPaired && _deviceId != null) {
        AppLogger.info('Sending handshake for device: $_deviceId');
        await _wsService.sendHandshake(deviceId: _deviceId!);

        // Wait for HANDSHAKE_RESPONSE
        final handshakeSuccess = await _waitForHandshakeResponse();
        if (!handshakeSuccess) {
          AppLogger.warning('Handshake failed, device may need to re-pair');
          _isPaired = false;
          return false;
        }
      }

      // Update hub with connection time
      _currentHub = hub.copyWith(isPaired: true, lastConnected: DateTime.now());
      await _storageService.saveHubInfo(_currentHub!);
    }

    return success;
  }

  /// Pair with a new hub from QR code
  Future<bool> pairWithHub(HubInfo hub, String sharedSecret) async {
    AppLogger.info('Pairing with hub: ${hub.name}');
    AppLogger.info('Shared secret length: ${sharedSecret.length} chars');

    // Save shared secret and set key BEFORE connecting
    await _storageService.saveSharedSecret(sharedSecret);
    _encryptionService.setKeyFromBase64(sharedSecret);
    AppLogger.info('Encryption key set from shared secret');

    // Connect to hub (but don't send handshake yet since we're not paired)
    _currentHub = hub;
    _hubChangedController.add(hub);

    final connected = await _wsService.connect(hub.endpoint);
    if (!connected) {
      AppLogger.error('Failed to connect for pairing');
      return false;
    }

    // Send pairing request
    final pairingToken = await _storageService.getPairingToken() ?? '';
    try {
      await _wsService.sendPairingRequest(
        deviceId: _deviceId!,
        deviceName: _deviceName!,
        platform: Platform.isIOS ? 'iOS' : 'Android',
        pairingToken: pairingToken,
      );
    } catch (e) {
      AppLogger.error('Failed to send pairing request', error: e);
      return false;
    }

    // Wait for PAIRING_RESPONSE
    final pairingSuccess = await _waitForPairingResponse();
    if (!pairingSuccess) {
      AppLogger.error('Pairing rejected by server');
      await _storageService.deleteSharedSecret();
      _encryptionService.clearKey();
      return false;
    }

    _isPaired = true;
    _currentHub = hub.copyWith(isPaired: true, lastConnected: DateTime.now());
    await _storageService.saveHubInfo(_currentHub!);

    AppLogger.info('Pairing successful');
    return true;
  }

  /// Wait for PAIRING_RESPONSE message
  Future<bool> _waitForPairingResponse() async {
    try {
      final response = await _wsService.messageStream
          .where((msg) => msg['type'] == 'PAIRING_RESPONSE')
          .first
          .timeout(const Duration(seconds: 10));

      final success = response['success'] == true;
      if (!success) {
        AppLogger.error('Pairing failed: ${response['message']}');
      }
      return success;
    } catch (e) {
      AppLogger.error('Timeout waiting for PAIRING_RESPONSE', error: e);
      return false;
    }
  }

  /// Wait for HANDSHAKE_RESPONSE message
  Future<bool> _waitForHandshakeResponse() async {
    try {
      final response = await _wsService.messageStream
          .where((msg) => msg['type'] == 'HANDSHAKE_RESPONSE')
          .first
          .timeout(const Duration(seconds: 10));

      final success = response['success'] == true;
      if (!success) {
        AppLogger.error('Handshake failed: ${response['error']}');
      }
      return success;
    } catch (e) {
      AppLogger.error('Timeout waiting for HANDSHAKE_RESPONSE', error: e);
      return false;
    }
  }

  /// Disconnect from current hub
  Future<void> disconnect() async {
    await _wsService.disconnect();
  }

  /// Reconnect to current hub
  Future<bool> reconnect() async {
    if (_currentHub == null) return false;
    return await connect(_currentHub!);
  }

  /// Unpair from current hub
  Future<void> unpair() async {
    AppLogger.info('Unpairing from hub');

    await disconnect();
    await _storageService.deleteSharedSecret();
    await _storageService.clearHubInfo();
    _encryptionService.clearKey();

    _currentHub = null;
    _isPaired = false;
    _hubChangedController.add(null);
  }

  /// Start discovering hubs on the network
  Future<void> startDiscovery() async {
    await _discoveryService.startDiscovery();
  }

  /// Stop discovering hubs
  Future<void> stopDiscovery() async {
    await _discoveryService.stopDiscovery();
  }

  /// Get discovered hubs stream
  Stream<List<HubInfo>> get discoveredHubsStream =>
      _discoveryService.hubsStream;

  /// Get discovered hubs
  List<HubInfo> get discoveredHubs => _discoveryService.discoveredHubs;

  /// Update device name
  Future<void> setDeviceName(String name) async {
    _deviceName = name;
    await _storageService.saveDeviceName(name);
  }

  Future<String> _getDefaultDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        return android.model;
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        return ios.name;
      }
    } catch (e) {
      AppLogger.error('Failed to get device name', error: e);
    }

    return 'Mobile Device';
  }

  /// Dispose resources
  void dispose() {
    _connectionStateController.close();
    _hubChangedController.close();
  }
}
