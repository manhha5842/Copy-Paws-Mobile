import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Logging utility for consistent app logging
class AppLogger {
  AppLogger._();

  static const String _tag = 'CopyPaws';

  /// Log info message
  static void info(String message, {String? tag}) {
    _log('INFO', message, tag: tag);
  }

  /// Log debug message
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      _log('DEBUG', message, tag: tag);
    }
  }

  /// Log warning message
  static void warning(String message, {String? tag}) {
    _log('WARN', message, tag: tag);
  }

  /// Log error message
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log('ERROR', message, tag: tag);
    if (error != null) {
      _log('ERROR', error.toString(), tag: tag);
    }
    if (stackTrace != null && kDebugMode) {
      _log('ERROR', stackTrace.toString(), tag: tag);
    }
  }

  /// Log WebSocket message
  static void ws(String message, {bool isIncoming = false}) {
    final prefix = isIncoming ? '<<<' : '>>>';
    _log('WS', '$prefix $message');
  }

  /// Log network activity
  static void network(String message) {
    _log('NET', message);
  }

  static void _log(String level, String message, {String? tag}) {
    final logTag = tag ?? _tag;
    final timestamp = DateTime.now().toString().substring(
      11,
      23,
    ); // HH:mm:ss.mmm
    final formattedMessage = '[$timestamp] [$level] [$logTag] $message';

    // Always print to console in debug mode for visibility in flutter run
    if (kDebugMode) {
      print(formattedMessage); // This shows in flutter run terminal
      developer.log(message, name: logTag, time: DateTime.now());
    }

    // TODO: Add file logging or crash reporting in production
  }
}
