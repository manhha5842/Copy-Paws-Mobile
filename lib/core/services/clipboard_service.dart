import 'dart:async';

import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Clipboard service for reading/writing system clipboard
class ClipboardService {
  ClipboardService._();
  static final ClipboardService instance = ClipboardService._();

  // Stream controller for clipboard changes
  final _clipboardChangeController = StreamController<String>.broadcast();

  // Timer for clipboard monitoring
  Timer? _pollTimer;
  String? _lastContent;
  bool _isMonitoring = false;

  // Getters
  Stream<String> get clipboardChangeStream => _clipboardChangeController.stream;
  bool get isMonitoring => _isMonitoring;
  String? get lastKnownContent => _lastContent;

  /// Get current clipboard content
  Future<String?> getContent() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (e) {
      AppLogger.error('Failed to read clipboard', error: e);
      return null;
    }
  }

  /// Set clipboard content
  Future<bool> setContent(String content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      _lastContent = content;
      AppLogger.info('Clipboard content set (${content.length} chars)');
      return true;
    } catch (e) {
      AppLogger.error('Failed to set clipboard', error: e);
      return false;
    }
  }

  /// Start monitoring clipboard changes
  /// Note: This uses polling as there's no native clipboard change listener
  void startMonitoring({Duration interval = const Duration(seconds: 2)}) {
    if (_isMonitoring) {
      AppLogger.warning('Clipboard monitoring already active');
      return;
    }

    AppLogger.info('Starting clipboard monitoring');
    _isMonitoring = true;

    // Get initial content
    getContent().then((content) {
      _lastContent = content;
    });

    _pollTimer = Timer.periodic(interval, (_) async {
      final content = await getContent();
      if (content != null && content != _lastContent && content.isNotEmpty) {
        AppLogger.debug('Clipboard changed: ${content.length} chars');
        _lastContent = content;
        _clipboardChangeController.add(content);
      }
    });
  }

  /// Stop monitoring clipboard changes
  void stopMonitoring() {
    if (!_isMonitoring) return;

    AppLogger.info('Stopping clipboard monitoring');
    _pollTimer?.cancel();
    _pollTimer = null;
    _isMonitoring = false;
  }

  /// Check if clipboard has content
  Future<bool> hasContent() async {
    final content = await getContent();
    return content != null && content.isNotEmpty;
  }

  /// Clear clipboard (set to empty string)
  Future<void> clear() async {
    await setContent('');
    _lastContent = '';
  }

  /// Copy text and get content (utility method)
  Future<String?> copyAndGet(String content) async {
    final success = await setContent(content);
    if (success) {
      return content;
    }
    return null;
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _clipboardChangeController.close();
  }
}
