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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE clips (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            source_device TEXT,
            source_app TEXT,
            is_from_hub INTEGER NOT NULL DEFAULT 1,
            is_pinned INTEGER NOT NULL DEFAULT 0
          )
        ''');
        AppLogger.info('Database created');
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

  /// Get show preview
  bool get showPreview => _prefs?.getBool(StorageKeys.showPreview) ?? true;

  /// Set show preview
  Future<void> setShowPreview(bool enabled) async {
    await _prefs?.setBool(StorageKeys.showPreview, enabled);
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
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get clipboard history
  Future<List<ClipboardItem>> getClipHistory({int limit = 100}) async {
    if (_database == null) return [];

    final results = await _database!.query(
      'clips',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return results
        .map(
          (row) => ClipboardItem(
            id: row['id'] as String,
            content: row['content'] as String,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              row['timestamp'] as int,
            ),
            sourceDevice: row['source_device'] as String?,
            sourceApp: row['source_app'] as String?,
            isFromHub: (row['is_from_hub'] as int) == 1,
          ),
        )
        .toList();
  }

  /// Search clips
  Future<List<ClipboardItem>> searchClips(String query) async {
    if (_database == null) return [];

    final results = await _database!.query(
      'clips',
      where: 'content LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'timestamp DESC',
      limit: 50,
    );

    return results
        .map(
          (row) => ClipboardItem(
            id: row['id'] as String,
            content: row['content'] as String,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              row['timestamp'] as int,
            ),
            sourceDevice: row['source_device'] as String?,
            sourceApp: row['source_app'] as String?,
            isFromHub: (row['is_from_hub'] as int) == 1,
          ),
        )
        .toList();
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
}
