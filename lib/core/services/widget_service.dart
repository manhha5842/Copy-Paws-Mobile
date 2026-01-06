import 'package:home_widget/home_widget.dart';

import '../models/clipboard_item.dart';
import '../utils/logger.dart';

/// Service to manage home screen widgets
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  // Widget config
  // Note: These must match the names in Android/iOS native code
  static const String _androidWidgetName =
      'com.example.copypaws.CopyPawsWidgetProvider';
  static const String _iOSWidgetName = 'CopyPawsWidget';
  static const String _appGroupId = 'group.com.example.copypaws';

  /// Initialize
  Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Update widget with latest clips
  Future<void> updateWidget(List<ClipboardItem> clips) async {
    try {
      AppLogger.info('Updating widget with ${clips.length} clips');

      // Save top 3 clips
      for (int i = 0; i < 3; i++) {
        final prefix = 'clip_$i';
        if (i < clips.length) {
          final clip = clips[i];
          await HomeWidget.saveWidgetData<String>(
            '${prefix}_content',
            clip.content,
          );
          await HomeWidget.saveWidgetData<String>(
            '${prefix}_source',
            clip.sourceDevice ?? 'Unknown',
          );
          await HomeWidget.saveWidgetData<String>(
            '${prefix}_time',
            clip.formattedTime,
          );
        } else {
          // Clear if no clip
          await HomeWidget.saveWidgetData<String>('${prefix}_content', '');
          await HomeWidget.saveWidgetData<String>('${prefix}_source', '');
          await HomeWidget.saveWidgetData<String>('${prefix}_time', '');
        }
      }

      // Also save the very first one as "clip_content" for backward compat or single-view logic if needed
      if (clips.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>(
          'clip_content',
          clips.first.content,
        );
      }

      // Update widget appearance
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      AppLogger.error('Failed to update widget', error: e);
    }
  }

  /// Register for background interaction
  Future<void> registerBackgroundCallback(void Function(Uri?) callback) async {
    // TODO: Implement background interactivity
    // await HomeWidget.registerInteractivityCallback(callback);
  }
}
