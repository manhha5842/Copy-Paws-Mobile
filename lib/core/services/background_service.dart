import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'connection_manager.dart';
import 'storage_service.dart';
import 'sync_service.dart';
import '../utils/logger.dart';
import '../constants/connection_state.dart' as app_state;

class BackgroundService {
  static const String notificationChannelId = 'copypaws_bg_service';
  static const int notificationId = 888;

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
        isForegroundMode: true,

        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'CopyPaws Service',
        initialNotificationContent: 'Initializing...',
        foregroundServiceNotificationId: notificationId,
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

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    // Return true if successful processing
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Only available for flutter 3.0.0 and later
    DartPluginRegistrant.ensureInitialized();

    AppLogger.info('Background Service: Started');

    // Initialize services that are needed in background
    // Note: Since this runs in a separate isolate, singletons in the main app won't be shared.
    // We need to re-initialize them.

    try {
      final storage = StorageService.instance;
      await storage.initialize();

      // EncryptionService is synchronous and lazy-loaded, no init needed

      final connectionManager = ConnectionManager.instance;
      await connectionManager.initialize();

      final syncService = SyncService.instance;
      await syncService.initialize();

      // Listen for stop request
      service.on('stopService').listen((event) {
        service.stopSelf();
      });

      // Update notification based on connection state
      connectionManager.connectionStateStream.listen((state) async {
        String statusText;
        switch (state) {
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
            statusText = 'Disconnected';
            break;
          case app_state.ConnectionState.error:
            statusText = 'Connection failed';
            break;
        }

        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            service.setForegroundNotificationInfo(
              title: 'CopyPaws',
              content: statusText,
            );
          }
        }

        AppLogger.info('Background Service: Connection State -> $state');
      });

      // Attempt to auto-connect
      // If the app was just killed, this will pick up the connection in the background
      AppLogger.info('Background Service: Attempting auto-connect...');
      await connectionManager.autoConnect();
    } catch (e, stack) {
      AppLogger.error('Background Service Error', error: e, stackTrace: stack);
    }
  }
}
