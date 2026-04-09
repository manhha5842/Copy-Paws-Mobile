import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'connection_manager.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import 'sync_service.dart';
import '../utils/logger.dart';
import '../constants/connection_state.dart' as app_state;

class BackgroundService {
  static const String notificationChannelId = 'copypaws_bg_service';
  static const int notificationId = 888;
  static const String _connectionStatusMethod = 'connection_status';
  static const String _requestConnectionStatusMethod =
      'request_connection_status';
  static const String _requestLatestMethod = 'request_latest';
  static const String _pushClipboardTextMethod = 'push_clip_text';
  static const String _disconnectHubMethod = 'disconnect_hub';

  static Stream<BackgroundConnectionSnapshot> get connectionSnapshotStream {
    if (!Platform.isAndroid) {
      return const Stream<BackgroundConnectionSnapshot>.empty();
    }

    return FlutterBackgroundService()
        .on(_connectionStatusMethod)
        .where((event) {
          return event != null;
        })
        .map(
          (event) => BackgroundConnectionSnapshot.fromMap(
            Map<String, dynamic>.from(event!),
          ),
        );
  }

  static void requestConnectionSnapshot() {
    if (!Platform.isAndroid) return;
    FlutterBackgroundService().invoke(_requestConnectionStatusMethod);
  }

  static void requestLatestFromBackground() {
    if (!Platform.isAndroid) return;
    FlutterBackgroundService().invoke(_requestLatestMethod);
  }

  static void pushClipboardText(String text) {
    if (!Platform.isAndroid || text.isEmpty) return;
    FlutterBackgroundService().invoke(_pushClipboardTextMethod, {'text': text});
  }

  static void disconnectHubInBackground() {
    if (!Platform.isAndroid) return;
    FlutterBackgroundService().invoke(_disconnectHubMethod);
  }

  static Future<void> _setForegroundStatus(
    ServiceInstance service,
    String statusText,
  ) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        await service.setForegroundNotificationInfo(
          title: 'CopyPaws',
          content: statusText,
        );
      }
    }

    AppLogger.info('Background Service: Notification -> $statusText');
  }

  static Future<void> _updateForegroundNotification(
    ServiceInstance service,
    ConnectionManager connectionManager,
  ) async {
    String statusText;
    switch (connectionManager.connectionState) {
      case app_state.ConnectionState.connected:
        statusText =
            'Connected to ${connectionManager.currentHub?.name ?? "Hub"}';
        break;
      case app_state.ConnectionState.connecting:
      case app_state.ConnectionState.authenticating:
      case app_state.ConnectionState.discovering:
        statusText = 'Connecting...';
        break;
      case app_state.ConnectionState.disconnected:
      case app_state.ConnectionState.paused:
        statusText = connectionManager.currentHub == null
            ? 'Waiting for setup'
            : 'Disconnected';
        break;
      case app_state.ConnectionState.error:
        statusText = 'Connection failed';
        break;
    }

    await _setForegroundStatus(service, statusText);
  }

  static Future<void> _broadcastConnectionSnapshot(
    ServiceInstance service,
    ConnectionManager connectionManager,
  ) async {
    await StorageService.instance.saveBackgroundConnectionSnapshot(
      connectionState: connectionManager.connectionState.name,
      hubName: connectionManager.currentHub?.name,
      hubEndpoint: connectionManager.currentHub?.endpoint,
      isConnected: connectionManager.isConnected,
    );

    service.invoke(_connectionStatusMethod, {
      'connectionState': connectionManager.connectionState.name,
      'hubName': connectionManager.currentHub?.name,
      'hubEndpoint': connectionManager.currentHub?.endpoint,
      'isConnected': connectionManager.isConnected,
    });
  }

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'CopyPaws Background Service',
      description: 'Used for keeping the connection to Desktop Hub alive',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // This will be executed when app is in foreground or background in separate isolate
        onStart: onStart,

        // auto start service
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,

        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'CopyPaws Service',
        initialNotificationContent: 'Initializing...',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        // Auto start service
        autoStart: true,

        // this will be executed when app is in foreground in separate isolate
        // or when background fetch is triggered
        onForeground: onStart,

        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<bool> ensureRunning() async {
    if (!Platform.isAndroid) return false;

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) return true;

    return service.startService();
  }

  static Future<bool> isRunning() async {
    if (!Platform.isAndroid) return false;
    return FlutterBackgroundService().isRunning();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    // Return true if successful processing
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Initialize services that are needed in background
    // Note: Since this runs in a separate isolate, singletons in the main app won't be shared.
    // We need to re-initialize them.

    try {
      await _setForegroundStatus(service, 'Starting background isolate...');

      // Only available for flutter 3.0.0 and later.
      // Keep this inside try so bootstrap failures surface in the notification.
      DartPluginRegistrant.ensureInitialized();

      AppLogger.info('Background Service: Started');

      final storage = StorageService.instance;
      await _setForegroundStatus(service, 'Initializing storage...');
      await storage.initialize();

      // Background isolates do not share singleton state with the UI isolate,
      // so notifications must be initialized again here.
      await _setForegroundStatus(service, 'Initializing notifications...');
      await NotificationService.instance.initialize();

      // EncryptionService is synchronous and lazy-loaded, no init needed

      final connectionManager = ConnectionManager.instance;
      await _setForegroundStatus(service, 'Initializing connection...');
      await connectionManager.initialize();

      final syncService = SyncService.instance;
      await _setForegroundStatus(service, 'Initializing sync...');
      await syncService.initialize();

      // Listen for stop request
      service.on('stopService').listen((event) {
        service.stopSelf();
      });

      service.on(_requestConnectionStatusMethod).listen((event) async {
        await _broadcastConnectionSnapshot(service, connectionManager);
      });

      service.on(_requestLatestMethod).listen((event) async {
        await syncService.requestLatest();
        await _broadcastConnectionSnapshot(service, connectionManager);
      });

      service.on(_pushClipboardTextMethod).listen((event) async {
        final payload = event != null
            ? Map<String, dynamic>.from(event)
            : const <String, dynamic>{};
        final text = payload['text'] as String? ?? '';
        if (text.isEmpty) return;
        await syncService.pushContent(text);
        await _broadcastConnectionSnapshot(service, connectionManager);
      });

      service.on(_disconnectHubMethod).listen((event) async {
        await connectionManager.disconnect();
        await _broadcastConnectionSnapshot(service, connectionManager);
      });

      // Update notification based on connection state
      connectionManager.connectionStateStream.listen((state) async {
        await _updateForegroundNotification(service, connectionManager);
        await _broadcastConnectionSnapshot(service, connectionManager);
        AppLogger.info('Background Service: Connection State -> $state');
      });

      connectionManager.hubChangedStream.listen((hub) async {
        await _broadcastConnectionSnapshot(service, connectionManager);
      });

      // Show the actual current state immediately instead of leaving the
      // foreground notification stuck at "Initializing...".
      await _updateForegroundNotification(service, connectionManager);
      await _broadcastConnectionSnapshot(service, connectionManager);

      // Attempt to auto-connect
      // If the app was just killed, this will pick up the connection in the background
      AppLogger.info('Background Service: Attempting auto-connect...');
      final autoConnected = await connectionManager.autoConnect();
      if (!autoConnected) {
        await _updateForegroundNotification(service, connectionManager);
      }
      await _broadcastConnectionSnapshot(service, connectionManager);
    } catch (e, stack) {
      final errorText = e.toString().replaceAll('\n', ' ');
      final shortened = errorText.length > 80
          ? '${errorText.substring(0, 80)}...'
          : errorText;
      await _setForegroundStatus(service, 'Startup error: $shortened');
      AppLogger.error('Background Service Error', error: e, stackTrace: stack);
    }
  }
}

class BackgroundConnectionSnapshot {
  const BackgroundConnectionSnapshot({
    required this.connectionState,
    required this.isConnected,
    this.hubName,
    this.hubEndpoint,
  });

  factory BackgroundConnectionSnapshot.fromMap(Map<String, dynamic> map) {
    return BackgroundConnectionSnapshot(
      connectionState: app_state.ConnectionStateX.fromString(
        map['connectionState'] as String?,
      ),
      isConnected: map['isConnected'] as bool? ?? false,
      hubName: map['hubName'] as String?,
      hubEndpoint: map['hubEndpoint'] as String?,
    );
  }

  final app_state.ConnectionState connectionState;
  final bool isConnected;
  final String? hubName;
  final String? hubEndpoint;
}
