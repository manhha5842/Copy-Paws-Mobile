import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../constants/message_types.dart';
import '../models/clipboard_item.dart';
import '../utils/logger.dart';
import 'websocket_service.dart';
import 'clipboard_service.dart';
import 'encryption_service.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'connection_manager.dart';
import 'widget_service.dart';

/// Sync service for clipboard synchronization with hub
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  // Services
  final _wsService = WebSocketService.instance;
  final _clipService = ClipboardService.instance;
  final _encryptionService = EncryptionService.instance;
  final _storageService = StorageService.instance;
  final _notificationService = NotificationService.instance;
  final _connectionManager = ConnectionManager.instance;
  final _widgetService = WidgetService.instance;

  // State
  final List<ClipboardItem> _incomingClips = [];
  StreamSubscription? _messageSubscription;
  StreamSubscription? _clipboardSubscription;
  bool _isInitialized = false;

  // Stream controllers
  final _incomingClipsController =
      StreamController<List<ClipboardItem>>.broadcast();
  final _newClipController = StreamController<ClipboardItem>.broadcast();

  // Getters
  List<ClipboardItem> get incomingClips => List.unmodifiable(_incomingClips);
  Stream<List<ClipboardItem>> get incomingClipsStream =>
      _incomingClipsController.stream;
  Stream<ClipboardItem> get newClipStream => _newClipController.stream;

  /// Initialize sync service
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.info('SyncService already initialized');
      return;
    }

    AppLogger.info('🚀 Initializing SyncService...');

    // Listen to WebSocket messages
    AppLogger.info('📡 Subscribing to WebSocket message stream...');
    _messageSubscription = _wsService.messageStream.listen(
      _handleMessage,
      onError: (error) {
        AppLogger.error('Message stream error', error: error);
      },
      onDone: () {
        AppLogger.warning('Message stream closed');
      },
    );
    AppLogger.info('✅ Subscribed to message stream successfully');

    // Load cached incoming clips
    final history = await _storageService.getClipHistory();
    _incomingClips.addAll(history.where((c) => c.isFromHub).take(20));
    _incomingClipsController.add(List.from(_incomingClips));

    // Initialize widget service
    await _widgetService.initialize();

    _isInitialized = true;
    AppLogger.info('✅ SyncService initialized successfully');
  }

  /// Start clipboard monitoring (for auto-push if enabled)
  void startClipboardMonitoring() {
    _clipboardSubscription?.cancel();
    _clipService.startMonitoring();

    // Note: Auto-push is disabled by default for privacy
    // User must manually push clips
  }

  /// Stop clipboard monitoring
  void stopClipboardMonitoring() {
    _clipboardSubscription?.cancel();
    _clipboardSubscription = null;
    _clipService.stopMonitoring();
  }

  /// Push current clipboard to hub
  Future<bool> pushClipboard() async {
    if (!_connectionManager.isConnected) {
      AppLogger.warning('Cannot push: not connected');
      return false;
    }

    if (!_encryptionService.hasKey) {
      AppLogger.warning('Cannot push: encryption key not set');
      return false;
    }

    // Get clipboard content
    final content = await _clipService.getContent();
    if (content == null || content.isEmpty) {
      AppLogger.warning('Cannot push: clipboard is empty');
      return false;
    }

    try {
      // Encrypt content
      final encrypted = _encryptionService.encrypt(content);

      // Send to hub
      await _wsService.sendClipPush(
        encryptedPayload: encrypted.ciphertext,
        iv: encrypted.iv,
        deviceName: _connectionManager.deviceName ?? 'Mobile',
      );

      // Save to local history
      final clip = ClipboardItem(
        id: const Uuid().v4(),
        content: content,
        timestamp: DateTime.now(),
        isFromHub: false,
      );
      await _storageService.saveClip(clip);

      AppLogger.info('Pushed clip to hub (${content.length} chars)');
      return true;
    } catch (e) {
      AppLogger.error('Failed to push clipboard', error: e);
      return false;
    }
  }

  /// Request latest clip from hub
  Future<void> requestLatest() async {
    if (!_connectionManager.isConnected) return;

    try {
      await _wsService.sendGetLatest();
      AppLogger.info('Requested latest clip from hub');
    } catch (e) {
      AppLogger.error('Failed to request latest', error: e);
    }
  }

  /// Copy an incoming clip to system clipboard
  Future<bool> copyToClipboard(ClipboardItem clip) async {
    final success = await _clipService.setContent(clip.content);
    if (success) {
      AppLogger.info('Copied clip to clipboard: ${clip.id}');
    }
    return success;
  }

  /// Delete a clip from local history
  Future<void> deleteClip(String clipId) async {
    _incomingClips.removeWhere((c) => c.id == clipId);
    _incomingClipsController.add(List.from(_incomingClips));
    await _storageService.deleteClip(clipId);
  }

  /// Clear all incoming clips
  void clearIncomingClips() {
    _incomingClips.clear();
    _incomingClipsController.add([]);
  }

  void _handleMessage(Map<String, dynamic> data) {
    final typeStr = data['type'] as String?;
    AppLogger.info('SyncService received message: type=$typeStr');

    if (typeStr == null) {
      AppLogger.warning('Message has no type field');
      return;
    }

    final type = MessageType.fromString(typeStr);
    AppLogger.info('Parsed message type: ${type?.value ?? "unknown"}');

    switch (type) {
      case MessageType.clipBroadcast:
      case MessageType.encrypted:
        AppLogger.info('Handling clip broadcast/encrypted message');
        _handleClipBroadcast(data);
        break;
      default:
        AppLogger.info(
          'Unhandled message type in SyncService: ${type?.value ?? "unknown"}',
        );
        break;
    }
  }

  Future<void> _handleClipBroadcast(Map<String, dynamic> data) async {
    AppLogger.info(
      '_handleClipBroadcast called with data: ${data.keys.toList()}',
    );

    if (!_encryptionService.hasKey) {
      AppLogger.error('Received clip but encryption key not set!');
      return;
    }

    AppLogger.info('Encryption key is available, processing...');

    try {
      String content;
      String clipId;
      String? sourceApp;
      int? timestamp;

      // Check if it's an ENCRYPTED wrapper
      if (data['type'] == 'ENCRYPTED') {
        // Desktop sends 'payload' field (not 'payload_encrypted') in ENCRYPTED wrapper
        final encryptedPayload =
            data['payload'] as String? ?? data['payload_encrypted'] as String?;
        final iv = data['iv'] as String?;

        AppLogger.info(
          'ENCRYPTED wrapper - payload field exists: ${data['payload'] != null}, iv exists: ${iv != null}',
        );

        if (encryptedPayload == null || iv == null) {
          AppLogger.error(
            'ENCRYPTED message missing payload or iv. Keys: ${data.keys.toList()}',
          );
          return;
        }

        // Decrypt outer layer to get inner CLIP_BROADCAST message
        AppLogger.info('Decrypting ENCRYPTED wrapper...');
        final decryptedJson = _encryptionService.decrypt(encryptedPayload, iv);
        AppLogger.info(
          'Decrypted inner JSON: ${decryptedJson.substring(0, decryptedJson.length.clamp(0, 100))}...',
        );
        final innerData = jsonDecode(decryptedJson) as Map<String, dynamic>;
        AppLogger.info('Inner message type: ${innerData['type']}');

        // Check inner message type
        if (innerData['type'] == 'CLIP_BROADCAST') {
          // IMPORTANT: After decrypting ENCRYPTED wrapper, the inner payload_encrypted
          // is already PLAINTEXT (the actual clipboard content), NOT encrypted again!
          // This matches how test-client handles it
          content =
              innerData['payload_encrypted'] as String? ??
              innerData['content'] as String? ??
              '';

          AppLogger.info(
            'Extracted content from inner CLIP_BROADCAST: ${content.length} chars',
          );

          clipId = innerData['clip_id'] as String? ?? const Uuid().v4();
          sourceApp = innerData['source_app'] as String?;
          timestamp = innerData['timestamp'] as int?;
        } else {
          // Single-layer encrypted content (rare case)
          content = decryptedJson;
          clipId = const Uuid().v4();
          AppLogger.info('Single-layer content: ${content.length} chars');
        }
      } else {
        // Direct CLIP_BROADCAST
        final encryptedPayload = data['payload_encrypted'] as String?;
        final iv = data['iv'] as String?;

        if (encryptedPayload != null && iv != null) {
          content = _encryptionService.decrypt(encryptedPayload, iv);
        } else {
          content = data['content'] as String? ?? '';
        }

        clipId = data['clip_id'] as String? ?? const Uuid().v4();
        sourceApp = data['source_app'] as String?;
        timestamp = data['timestamp'] as int?;
      }

      if (content.isEmpty) {
        AppLogger.warning('Received empty clip content');
        return;
      }

      AppLogger.info(
        'Successfully decrypted clip content: ${content.length} chars',
      );

      final clip = ClipboardItem(
        id: clipId,
        content: content,
        timestamp: timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : DateTime.now(),
        sourceDevice: _connectionManager.currentHub?.name,
        sourceApp: sourceApp,
        isFromHub: true,
      );

      // Add to incoming clips
      _incomingClips.insert(0, clip);
      if (_incomingClips.length > 50) {
        _incomingClips.removeLast();
      }
      _incomingClipsController.add(List.from(_incomingClips));
      _newClipController.add(clip);

      // Save to database
      _storageService.saveClip(clip);

      // Show notification
      if (_storageService.notificationsEnabled) {
        _notificationService.showNewClipNotification(
          title: 'New clip from ${clip.sourceDevice ?? "Hub"}',
          body: clip.preview,
          clipId: clip.id,
        );
      }

      // Update home screen widget
      await _widgetService.updateWidget(List.from(_incomingClips));

      AppLogger.info(
        '🎉 Successfully received and processed clip from hub: ${content.length} chars',
      );
    } catch (e, stackTrace) {
      AppLogger.error('❌ Failed to process incoming clip', error: e);
      AppLogger.error('Stack trace:', error: stackTrace);
    }
  }

  /// Dispose resources
  void dispose() {
    _messageSubscription?.cancel();
    _clipboardSubscription?.cancel();
    _incomingClipsController.close();
    _newClipController.close();
  }
}
