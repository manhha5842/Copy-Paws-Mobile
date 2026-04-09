import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Android-only helpers for system settings that affect long-running sync.
class BackgroundPermissionService {
  BackgroundPermissionService._();
  static final BackgroundPermissionService instance =
      BackgroundPermissionService._();

  static const MethodChannel _channel = MethodChannel(
    'system_settings_channel',
  );

  bool get isSupported => Platform.isAndroid;

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!isSupported) return true;

    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to check battery optimization status',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!isSupported) return true;

    try {
      return await _channel.invokeMethod<bool>(
            'requestIgnoreBatteryOptimizations',
          ) ??
          false;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to request battery optimization exemption',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  Future<bool> openBatteryOptimizationSettings() async {
    if (!isSupported) return true;

    try {
      return await _channel.invokeMethod<bool>(
            'openBatteryOptimizationSettings',
          ) ??
          false;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to open battery optimization settings',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }
}
