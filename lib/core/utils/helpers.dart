import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Helper utilities for common operations
class Helpers {
  Helpers._();

  /// Generate a unique ID
  static String generateId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generate a short ID (8 chars)
  static String generateShortId() {
    return generateId().substring(0, 8);
  }

  /// Truncate string with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format duration
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Format relative time
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// Check if running on mobile
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Check if running on iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Check if running on Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Get device platform string
  static String get platformString {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Validate IP address
  static bool isValidIpAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }

    return true;
  }

  /// Validate port number
  static bool isValidPort(String port) {
    final num = int.tryParse(port);
    return num != null && num > 0 && num <= 65535;
  }

  /// Extract IP from WebSocket URL
  static String? extractIpFromWsUrl(String wsUrl) {
    final regex = RegExp(r'ws://(\d+\.\d+\.\d+\.\d+):');
    final match = regex.firstMatch(wsUrl);
    return match?.group(1);
  }

  /// Extract port from WebSocket URL
  static int? extractPortFromWsUrl(String wsUrl) {
    final regex = RegExp(r':(\d+)');
    final match = regex.firstMatch(wsUrl);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }
}
