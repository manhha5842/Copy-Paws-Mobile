import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/logger.dart';

/// Notification service for local push notifications
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Notification IDs
  static const int connectionStatusId = 1;
  static const int newClipBaseId = 1000;

  // Channels
  static const String clipsChannelId = 'clips';
  static const String clipsChannelName = 'New Clips';
  static const String clipsChannelDesc =
      'Notifications for new clipboard items';

  static const String connectionChannelId = 'connection';
  static const String connectionChannelName = 'Connection Status';
  static const String connectionChannelDesc = 'Connection status notifications';

  // Callback for notification taps
  Function(String? payload)? onNotificationTap;

  /// Initialize notification service
  Future<bool> initialize() async {
    if (_initialized) return true;

    AppLogger.info('Initializing notification service');

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final result = await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _initialized = result ?? false;
    AppLogger.info('Notification service initialized: $_initialized');

    return _initialized;
  }

  /// Request notification permissions
  Future<bool> requestPermission() async {
    if (!_initialized) await initialize();

    if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } else if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }

    return true;
  }

  /// Show new clip notification
  Future<void> showNewClipNotification({
    required String title,
    required String body,
    String? clipId,
  }) async {
    if (!_initialized) return;

    final id = clipId != null
        ? clipId.hashCode
        : newClipBaseId + DateTime.now().millisecondsSinceEpoch % 1000;

    const androidDetails = AndroidNotificationDetails(
      clipsChannelId,
      clipsChannelName,
      channelDescription: clipsChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: clipId);

    AppLogger.debug('Showed notification: $title');
  }

  /// Show connection status notification (persistent on Android)
  Future<void> showConnectionNotification({
    required String title,
    required String body,
    bool ongoing = false,
  }) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      connectionChannelId,
      connectionChannelName,
      channelDescription: connectionChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: ongoing,
      autoCancel: !ongoing,
      category: AndroidNotificationCategory.service,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(connectionStatusId, title, body, details);
  }

  /// Cancel notification by ID
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Cancel connection notification
  Future<void> cancelConnectionNotification() async {
    await cancel(connectionStatusId);
  }

  void _onNotificationResponse(NotificationResponse response) {
    AppLogger.debug('Notification tapped: ${response.payload}');
    onNotificationTap?.call(response.payload);
  }
}
