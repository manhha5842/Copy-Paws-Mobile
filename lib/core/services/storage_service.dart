import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../constants/storage_keys.dart';
import '../models/clipboard_item.dart';
import '../models/hub_info.dart';
import '../utils/logger.dart';

/// Storage service for local and secure storage
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  // Storage instances
  late FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;
  Database? _database;

  bool _initialized = false;

  /// Initialize storage service
  Future<void> initialize() async {
    if (_initialized) return;

    AppLogger.info('Initializing storage service');

    // Initialize secure storage
    _secureStorage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );

    // Initialize shared preferences
    _prefs = await SharedPreferences.getInstance();

    // Initialize SQLite database
    await _initDatabase();

    _initialized = true;
    AppLogger.info('Storage service initialized');
  }

  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'copypaws.db');

    _database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE clips (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            source_device TEXT,
            source_app TEXT,
            is_from_hub INTEGER NOT NULL DEFAULT 1,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            content_type TEXT NOT NULL DEFAULT 'text',
            mime_type TEXT,
            content_size INTEGER,
            thumbnail_path TEXT
          )
        ''');
        AppLogger.info('Database created');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE clips ADD COLUMN content_type TEXT NOT NULL DEFAULT 'text'",
          );
          await db.execute('ALTER TABLE clips ADD COLUMN mime_type TEXT');
          await db.execute('ALTER TABLE clips ADD COLUMN content_size INTEGER');
          await db.execute('ALTER TABLE clips ADD COLUMN thumbnail_path TEXT');
          AppLogger.info('Database upgraded to version 2');
        }
      },
    );
  }

  // ===== Secure Storage (Keychain/Keystore) =====

  /// Save shared secret securely
  Future<void> saveSharedSecret(String secret) async {
    await _secureStorage.write(key: StorageKeys.sharedSecret, value: secret);
    AppLogger.info('Shared secret saved');
  }

  /// Get shared secret
  Future<String?> getSharedSecret() async {
    return await _secureStorage.read(key: StorageKeys.sharedSecret);
  }

  /// Delete shared secret
  Future<void> deleteSharedSecret() async {
    await _secureStorage.delete(key: StorageKeys.sharedSecret);
    AppLogger.info('Shared secret deleted');
  }

  /// Save pairing token
  Future<void> savePairingToken(String token) async {
    await _secureStorage.write(key: StorageKeys.pairingToken, value: token);
  }

  /// Get pairing token
  Future<String?> getPairingToken() async {
    return await _secureStorage.read(key: StorageKeys.pairingToken);
  }

  // ===== Device Info =====

  /// Save device ID
  Future<void> saveDeviceId(String deviceId) async {
    await _prefs?.setString(StorageKeys.deviceId, deviceId);
  }

  /// Get device ID
  String? getDeviceId() {
    return _prefs?.getString(StorageKeys.deviceId);
  }

  /// Save device name
  Future<void> saveDeviceName(String name) async {
    await _prefs?.setString(StorageKeys.deviceName, name);
  }

  /// Get device name
  String? getDeviceName() {
    return _prefs?.getString(StorageKeys.deviceName);
  }

  // ===== Hub Info =====

  /// Save paired hub info
  Future<void> saveHubInfo(HubInfo hub) async {
    await _prefs?.setString(StorageKeys.hubId, hub.id);
    await _prefs?.setString(StorageKeys.hubName, hub.name);
    await _prefs?.setString(StorageKeys.hubEndpoint, hub.endpoint);
    if (hub.ip != null) {
      await _prefs?.setString(StorageKeys.lastConnectedIp, hub.ip!);
    }
    if (hub.port != null) {
      await _prefs?.setInt(StorageKeys.lastConnectedPort, hub.port!);
    }
    AppLogger.info('Hub info saved: ${hub.name}');
  }

  /// Get paired hub info
  HubInfo? getHubInfo() {
    final id = _prefs?.getString(StorageKeys.hubId);
    final name = _prefs?.getString(StorageKeys.hubName);
    final endpoint = _prefs?.getString(StorageKeys.hubEndpoint);

    if (id == null || endpoint == null) return null;

    return HubInfo(
      id: id,
      name: name ?? 'Unknown Hub',
      endpoint: endpoint,
      ip: _prefs?.getString(StorageKeys.lastConnectedIp),
      port: _prefs?.getInt(StorageKeys.lastConnectedPort),
      isPaired: true,
    );
  }

  /// Clear hub info
  Future<void> clearHubInfo() async {
    await _prefs?.remove(StorageKeys.hubId);
    await _prefs?.remove(StorageKeys.hubName);
    await _prefs?.remove(StorageKeys.hubEndpoint);
    await _prefs?.remove(StorageKeys.lastConnectedIp);
    await _prefs?.remove(StorageKeys.lastConnectedPort);
    AppLogger.info('Hub info cleared');
  }

  // ===== Settings =====

  /// Get notifications enabled
  bool get notificationsEnabled =>
      _prefs?.getBool(StorageKeys.notificationsEnabled) ?? true;

  /// Set notifications enabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs?.setBool(StorageKeys.notificationsEnabled, enabled);
  }

  /// Get auto connect
  bool get autoConnect => _prefs?.getBool(StorageKeys.autoConnect) ?? true;

  /// Set auto connect
  Future<void> setAutoConnect(bool enabled) async {
    await _prefs?.setBool(StorageKeys.autoConnect, enabled);
  }

  /// Get sync enabled
  bool get syncEnabled => _prefs?.getBool(StorageKeys.syncEnabled) ?? true;

  /// Set sync enabled
  Future<void> setSyncEnabled(bool enabled) async {
    await _prefs?.setBool(StorageKeys.syncEnabled, enabled);
  }

  /// Get auto-copy for incoming clips while app is in foreground
  bool get autoCopyIncomingForeground =>
      _prefs?.getBool(StorageKeys.autoCopyIncomingForeground) ?? false;

  /// Set auto-copy for incoming clips while app is in foreground
  Future<void> setAutoCopyIncomingForeground(bool enabled) async {
    await _prefs?.setBool(StorageKeys.autoCopyIncomingForeground, enabled);
  }

  /// Get last auto-copied clip id.
  /// Used to avoid duplicate copies across UI and background isolates.
  String? get lastAutoCopiedClipId =>
      _prefs?.getString(StorageKeys.lastAutoCopiedClipId);

  /// Save last auto-copied clip id
  Future<void> setLastAutoCopiedClipId(String clipId) async {
    await _prefs?.setString(StorageKeys.lastAutoCopiedClipId, clipId);
  }

  /// Get show preview
  bool get showPreview => _prefs?.getBool(StorageKeys.showPreview) ?? true;

  /// Set show preview
  Future<void> setShowPreview(bool enabled) async {
    await _prefs?.setBool(StorageKeys.showPreview, enabled);
  }

  /// Reload shared preferences so values written by background isolates become visible.
  Future<void> reloadPreferences() async {
    await _prefs?.reload();
  }

  /// Persist the latest background connection snapshot for the UI isolate.
  Future<void> saveBackgroundConnectionSnapshot({
    required String connectionState,
    required bool isConnected,
    String? hubName,
    String? hubEndpoint,
  }) async {
    await _prefs?.setString(
      StorageKeys.backgroundConnectionState,
      connectionState,
    );
    await _prefs?.setBool(StorageKeys.backgroundIsConnected, isConnected);

    if (hubName == null || hubName.isEmpty) {
      await _prefs?.remove(StorageKeys.backgroundHubName);
    } else {
      await _prefs?.setString(StorageKeys.backgroundHubName, hubName);
    }

    if (hubEndpoint == null || hubEndpoint.isEmpty) {
      await _prefs?.remove(StorageKeys.backgroundHubEndpoint);
    } else {
      await _prefs?.setString(StorageKeys.backgroundHubEndpoint, hubEndpoint);
    }
  }

  /// Read the last background connection snapshot shared between isolates.
  Map<String, dynamic> getBackgroundConnectionSnapshot() {
    return {
      'connectionState': _prefs?.getString(
        StorageKeys.backgroundConnectionState,
      ),
      'hubName': _prefs?.getString(StorageKeys.backgroundHubName),
      'hubEndpoint': _prefs?.getString(StorageKeys.backgroundHubEndpoint),
      'isConnected':
          _prefs?.getBool(StorageKeys.backgroundIsConnected) ?? false,
    };
  }

  // ===== Clipboard History (SQLite) =====

  /// Save clipboard item to history
  Future<void> saveClip(ClipboardItem clip) async {
    if (_database == null) return;

    await _database!.insert('clips', {
      'id': clip.id,
      'content': clip.content,
      'timestamp': clip.timestamp.millisecondsSinceEpoch,
      'source_device': clip.sourceDevice,
      'source_app': clip.sourceApp,
      'is_from_hub': clip.isFromHub ? 1 : 0,
      'is_pinned': 0,
      'content_type': clip.contentType.value,
      'mime_type': clip.mimeType,
      'content_size': clip.contentSize,
      'thumbnail_path': clip.thumbnailPath,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Save clipboard item only if it does not already exist.
  /// Returns true when the clip was newly inserted.
  Future<bool> saveClipIfNew(ClipboardItem clip) async {
    if (_database == null) return false;

    final rowId = await _database!.insert('clips', {
      'id': clip.id,
      'content': clip.content,
      'timestamp': clip.timestamp.millisecondsSinceEpoch,
      'source_device': clip.sourceDevice,
      'source_app': clip.sourceApp,
      'is_from_hub': clip.isFromHub ? 1 : 0,
      'is_pinned': 0,
      'content_type': clip.contentType.value,
      'mime_type': clip.mimeType,
      'content_size': clip.contentSize,
      'thumbnail_path': clip.thumbnailPath,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    return rowId != 0;
  }

  /// Get clipboard history
  Future<List<ClipboardItem>> getClipHistory({int limit = 100}) async {
    if (_database == null) return [];

    try {
      final results = await _database!.rawQuery(
        '''
        SELECT
          id,
          CASE
            WHEN COALESCE(content_type, 'text') = 'image'
              OR COALESCE(mime_type, '') LIKE 'image/%'
            THEN ''
            ELSE SUBSTR(content, 1, 4096)
          END AS content,
          timestamp,
          source_device,
          source_app,
          is_from_hub,
          content_type,
          mime_type,
          content_size,
          thumbnail_path
        FROM clips
        ORDER BY timestamp DESC
        LIMIT ?
        ''',
        [limit],
      );

      return results.map(_mapClipRow).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to load clip history',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Search clips
  Future<List<ClipboardItem>> searchClips(String query) async {
    if (_database == null) return [];

    try {
      final results = await _database!.rawQuery(
        '''
        SELECT
          id,
          CASE
            WHEN COALESCE(content_type, 'text') = 'image'
              OR COALESCE(mime_type, '') LIKE 'image/%'
            THEN ''
            ELSE SUBSTR(content, 1, 4096)
          END AS content,
          timestamp,
          source_device,
          source_app,
          is_from_hub,
          content_type,
          mime_type,
          content_size,
          thumbnail_path
        FROM clips
        WHERE content LIKE ?
        ORDER BY timestamp DESC
        LIMIT 50
        ''',
        ['%$query%'],
      );

      return results.map(_mapClipRow).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to search clip history',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Load a single clip with its full content payload.
  Future<ClipboardItem?> getClipById(String id) async {
    if (_database == null) return null;

    try {
      final results = await _database!.query(
        'clips',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return _mapClipRow(results.first);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to load clip by id',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Delete clip by ID
  Future<void> deleteClip(String id) async {
    if (_database == null) return;
    await _database!.delete('clips', where: 'id = ?', whereArgs: [id]);
  }

  /// Clear all clips
  Future<void> clearClipHistory() async {
    if (_database == null) return;
    await _database!.delete('clips');
    AppLogger.info('Clip history cleared');
  }

  /// Get clip count
  Future<int> getClipCount() async {
    if (_database == null) return 0;
    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM clips',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all data
  Future<void> clearAll() async {
    await deleteSharedSecret();
    await clearHubInfo();
    await clearClipHistory();
    await _prefs?.clear();
    AppLogger.info('All storage cleared');
  }

  /// Close database
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  ClipboardItem _mapClipRow(Map<String, Object?> row) {
    final content = row['content'] as String? ?? '';
    final mimeType = row['mime_type'] as String?;
    final contentType = _resolveStoredContentType(
      content: content,
      storedValue: row['content_type'] as String?,
      mimeType: mimeType,
    );

    return ClipboardItem(
      id: row['id'] as String,
      content: content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      sourceDevice: row['source_device'] as String?,
      sourceApp: row['source_app'] as String?,
      isFromHub: (row['is_from_hub'] as int) == 1,
      contentType: contentType,
      mimeType: mimeType,
      contentSize: row['content_size'] as int?,
      thumbnailPath: row['thumbnail_path'] as String?,
    );
  }

  ClipboardContentType _resolveStoredContentType({
    required String content,
    String? storedValue,
    String? mimeType,
  }) {
    if (mimeType != null && mimeType.startsWith('image/')) {
      return ClipboardContentType.image;
    }

    if (storedValue != null &&
        storedValue.isNotEmpty &&
        storedValue != 'text') {
      return ClipboardContentTypeX.fromString(storedValue);
    }

    if (_looksLikeBase64Image(content)) {
      return ClipboardContentType.image;
    }

    return ClipboardContentTypeX.fromString(storedValue);
  }

  bool _looksLikeBase64Image(String content) {
    try {
      final normalized = content
          .trim()
          .replaceAll(RegExp(r'^data:[^;]+;base64,', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), '');
      if (normalized.length < 16) return false;

      final bytes = base64Decode(normalized);
      return _guessMimeTypeFromBytes(bytes) != null;
    } catch (_) {
      return false;
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
}
