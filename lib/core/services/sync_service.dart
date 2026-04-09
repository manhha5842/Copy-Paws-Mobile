import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  bool _isAppInForeground = false;

  // Stream controllers
  final _incomingClipsController =
      StreamController<List<ClipboardItem>>.broadcast();
  final _newClipController = StreamController<ClipboardItem>.broadcast();

  // Getters
  List<ClipboardItem> get incomingClips => List.unmodifiable(_incomingClips);
  Stream<List<ClipboardItem>> get incomingClipsStream =>
      _incomingClipsController.stream;
  Stream<ClipboardItem> get newClipStream => _newClipController.stream;

  /// Track whether the visible app isolate is currently in the foreground.
  /// Background isolates never set this to true, so auto-copy remains disabled there.
  void setAppInForeground(bool isForeground) {
    if (_isAppInForeground == isForeground) return;

    _isAppInForeground = isForeground;
    AppLogger.info('SyncService foreground state: $isForeground');
  }

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

    // Widgets are optional for sync; background isolates should keep running
    // even if widget integration is unavailable on a given device/runtime.
    try {
      await _widgetService.initialize();
    } catch (e, stackTrace) {
      AppLogger.warning('Widget service init failed, continuing without it');
      AppLogger.error(
        'Widget service init failure',
        error: e,
        stackTrace: stackTrace,
      );
    }

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
    // Get clipboard content
    final content = await _clipService.getContent();
    if (content == null || content.isEmpty) {
      AppLogger.warning('Cannot push: clipboard is empty');
      return false;
    }

    return pushContent(content);
  }

  /// Push provided content to hub.
  /// Useful when the active socket lives in a background isolate.
  Future<bool> pushContent(String content) async {
    if (!_connectionManager.isConnected) {
      AppLogger.warning('Cannot push: not connected');
      return false;
    }

    if (!_encryptionService.hasKey) {
      AppLogger.warning('Cannot push: encryption key not set');
      return false;
    }

    if (content.isEmpty) {
      AppLogger.warning('Cannot push: content is empty');
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
    final success = await _copyClipContent(clip);
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
      case MessageType.ping:
      case MessageType.pong:
      case MessageType.pairingResponse:
      case MessageType.handshakeResponse:
        AppLogger.debug(
          'Ignoring non-clipboard message in SyncService: $typeStr',
        );
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
      String? explicitContentType;
      String? mimeType;
      int? contentSize;
      String? thumbnailPath;

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
          explicitContentType = innerData['content_type'] as String?;
          mimeType = innerData['mime_type'] as String?;
          contentSize = innerData['content_size'] as int?;
          thumbnailPath = innerData['thumbnail_path'] as String?;
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
        explicitContentType = data['content_type'] as String?;
        mimeType = data['mime_type'] as String?;
        contentSize = data['content_size'] as int?;
        thumbnailPath = data['thumbnail_path'] as String?;
      }

      if (content.isEmpty) {
        AppLogger.warning('Received empty clip content');
        return;
      }

      final normalizedPayload = _normalizeIncomingClipPayload(
        content: content,
        explicitContentType: explicitContentType,
        explicitMimeType: mimeType,
        explicitContentSize: contentSize,
      );

      AppLogger.info(
        'Successfully decrypted clip content: ${content.length} chars',
      );

      final clip = ClipboardItem(
        id: clipId,
        content: normalizedPayload.content,
        timestamp: timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : DateTime.now(),
        sourceDevice: _connectionManager.currentHub?.name,
        sourceApp: sourceApp,
        isFromHub: true,
        contentType: normalizedPayload.contentType,
        mimeType: normalizedPayload.mimeType,
        contentSize: normalizedPayload.contentSize,
        thumbnailPath: thumbnailPath,
      );

      final isNewClip = await _storageService.saveClipIfNew(clip);
      if (!isNewClip) {
        final existsInMemory = _incomingClips.any((c) => c.id == clip.id);

        // If the background isolate stored the clip first, the foreground UI
        // still needs to surface it locally once without replaying side effects.
        if (_isAppInForeground && !existsInMemory) {
          _incomingClips.insert(0, clip);
          if (_incomingClips.length > 50) {
            _incomingClips.removeLast();
          }
          _incomingClipsController.add(List.from(_incomingClips));
        }

        AppLogger.debug('Skipping duplicate incoming clip: ${clip.id}');
        return;
      }

      // Add to incoming clips
      _incomingClips.insert(0, clip);
      if (_incomingClips.length > 50) {
        _incomingClips.removeLast();
      }
      _incomingClipsController.add(List.from(_incomingClips));
      _newClipController.add(clip);

      final shouldAutoCopy =
          _storageService.autoCopyIncomingForeground &&
          (_isAppInForeground || Platform.isAndroid);
      final alreadyCopied = _storageService.lastAutoCopiedClipId == clip.id;

      if (shouldAutoCopy && !alreadyCopied) {
        final copied = await _copyClipContent(clip);
        if (copied) {
          await _storageService.setLastAutoCopiedClipId(clip.id);
          AppLogger.info(
            'Auto-copied incoming clip'
            ' (foreground=$_isAppInForeground, platform=${Platform.operatingSystem})',
          );
        } else {
          AppLogger.warning('Failed to auto-copy incoming clip');
        }
      } else if (shouldAutoCopy && alreadyCopied) {
        AppLogger.debug('Skipping duplicate auto-copy for clip: ${clip.id}');
      }

      // Show notification
      if (_storageService.notificationsEnabled) {
        await _notificationService.showNewClipNotification(
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

  Future<bool> _copyClipContent(ClipboardItem clip) async {
    if (_shouldTreatClipAsImage(clip)) {
      return _clipService.setImageContent(
        base64Data: clip.content,
        mimeType: clip.mimeType ?? _guessMimeTypeFromBase64(clip.content),
        clipId: clip.id,
      );
    }

    return _clipService.setContent(clip.content);
  }

  bool _shouldTreatClipAsImage(ClipboardItem clip) {
    if (clip.isImage) return true;
    if (clip.mimeType != null && clip.mimeType!.startsWith('image/')) {
      return true;
    }
    return _looksLikeBase64Image(clip.content);
  }

  _NormalizedClipPayload _normalizeIncomingClipPayload({
    required String content,
    String? explicitContentType,
    String? explicitMimeType,
    int? explicitContentSize,
  }) {
    final trimmedContent = content.trim();
    final mimeTypeFromDataUri = _extractMimeTypeFromDataUri(trimmedContent);
    final normalizedContent = _stripDataUriPrefix(trimmedContent);
    final resolvedMimeType = explicitMimeType ?? mimeTypeFromDataUri;
    final resolvedContentType = _resolveContentType(
      explicitContentType: explicitContentType,
      mimeType: resolvedMimeType,
      normalizedContent: normalizedContent,
      originalContent: trimmedContent,
    );

    return _NormalizedClipPayload(
      content: resolvedContentType == ClipboardContentType.image
          ? normalizedContent
          : content,
      contentType: resolvedContentType,
      mimeType: resolvedContentType == ClipboardContentType.image
          ? (resolvedMimeType ?? _guessMimeTypeFromBase64(normalizedContent))
          : resolvedMimeType,
      contentSize: resolvedContentType == ClipboardContentType.image
          ? (explicitContentSize ??
                _computeBase64ContentSize(normalizedContent))
          : explicitContentSize,
    );
  }

  ClipboardContentType _resolveContentType({
    String? explicitContentType,
    String? mimeType,
    required String normalizedContent,
    required String originalContent,
  }) {
    final parsedType = ClipboardContentTypeX.fromString(explicitContentType);
    if (explicitContentType != null && explicitContentType.isNotEmpty) {
      return parsedType;
    }

    if (mimeType != null && mimeType.startsWith('image/')) {
      return ClipboardContentType.image;
    }

    if (originalContent.startsWith('data:image/')) {
      return ClipboardContentType.image;
    }

    if (_looksLikeBase64Image(normalizedContent)) {
      return ClipboardContentType.image;
    }

    return ClipboardContentType.text;
  }

  String _stripDataUriPrefix(String content) {
    final match = RegExp(
      r'^data:[^;]+;base64,(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(content);
    if (match == null) {
      return content.replaceAll(RegExp(r'\s+'), '');
    }
    return match.group(1)!.replaceAll(RegExp(r'\s+'), '');
  }

  String? _extractMimeTypeFromDataUri(String content) {
    final match = RegExp(
      r'^data:([^;]+);base64,',
      caseSensitive: false,
    ).firstMatch(content);
    return match?.group(1);
  }

  bool _looksLikeBase64Image(String content) {
    if (content.isEmpty || content.length < 16) return false;

    try {
      final bytes = base64Decode(content);
      return _guessMimeTypeFromBytes(bytes) != null;
    } catch (_) {
      return false;
    }
  }

  String? _guessMimeTypeFromBase64(String content) {
    try {
      return _guessMimeTypeFromBytes(base64Decode(content));
    } catch (_) {
      return null;
    }
  }

  String? _guessMimeTypeFromBytes(List<int> bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    if (bytes.length >= 6) {
      final header = ascii.decode(bytes.take(6).toList(), allowInvalid: true);
      if (header == 'GIF87a' || header == 'GIF89a') {
        return 'image/gif';
      }
    }

    if (bytes.length >= 12) {
      final riff = ascii.decode(bytes.take(4).toList(), allowInvalid: true);
      final webp = ascii.decode(
        bytes.skip(8).take(4).toList(),
        allowInvalid: true,
      );
      if (riff == 'RIFF' && webp == 'WEBP') {
        return 'image/webp';
      }
    }

    return null;
  }

  int? _computeBase64ContentSize(String content) {
    try {
      return base64Decode(content).length;
    } catch (_) {
      return null;
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

class _NormalizedClipPayload {
  const _NormalizedClipPayload({
    required this.content,
    required this.contentType,
    this.mimeType,
    this.contentSize,
  });

  final String content;
  final ClipboardContentType contentType;
  final String? mimeType;
  final int? contentSize;
}
