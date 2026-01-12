# 🤖 Android Widget Setup Guide

## Overview

CopyPaws Android widget provides quick access to clipboard functionality directly from the home screen. The widget displays the top 3 recent clips and includes Push/Pull action buttons.

## Features

✅ **Already Configured:**
- Widget provider class (`CopyPawsWidgetProvider.kt`)
- Widget layout with top 3 clips display
- Push and Pull action buttons
- Deep linking integration
- Automatic widget updates on clipboard changes

## Widget Installation

### 1. Build and Install the App

```bash
cd Mobile
flutter pub get
flutter build apk --debug  # or --release
flutter install
```

### 2. Add Widget to Home Screen

1. Long press on your Android home screen
2. Tap **Widgets**
3. Scroll to find **CopyPaws**
4. Long press and drag the widget to your home screen
5. Release to place the widget

## Widget Functionality

### Display Areas

The widget is divided into two sections:

**Left Section - Recent Clips:**
- Displays top 3 most recent clipboard items
- Shows clip content (truncated if too long)
- Updates automatically when new clips arrive

**Right Section - Action Buttons:**
- **Push**: Pushes current device clipboard to hub
- **Pull**: Requests latest clip from hub

### Widget Actions

| Action | URI | Behavior |
|--------|-----|----------|
| **Push** | `copypaws://push` | Pushes clipboard content to hub |
| **Pull** | `copypaws://pull` | Requests and pulls latest clip from hub |
| **Tap Widget** | `copypaws://open` | Opens the main app |

### How It Works

1. **Widget Clicks** → Android widget buttons trigger deep links
2. **Deep Links** → MainActivity receives `copypaws://` URIs
3. **MethodChannel** → MainActivity forwards actions to Flutter
4. **Widget Callback** → Flutter app handles the action (push/pull/open)
5. **Widget Update** → App updates widget data via HomeWidget plugin

## Technical Implementation

### Architecture

```
┌─────────────────┐
│  Android Widget │
│   (UI Layer)    │
└────────┬────────┘
         │ PendingIntent (copypaws://push)
         ▼
┌─────────────────┐
│  MainActivity   │
│  Deep Link      │
│  Handler        │
└────────┬────────┘
         │ MethodChannel
         ▼
┌─────────────────┐
│ WidgetService   │
│   (Flutter)     │
└────────┬────────┘
         │ Callback
         ▼
┌─────────────────┐
│  HomeScreen     │
│  Action Handler │
└─────────────────┘
```

### Files Modified

| File | Purpose |
|------|---------|
| `AndroidManifest.xml` | Added deep link intent filter for `copypaws://` scheme |
| `MainActivity.kt` | Implemented deep link handler with MethodChannel |
| `widget_service.dart` | Registered MethodChannel handler for widget actions |
| `home_screen.dart` | Enhanced widget action handling (push/pull/open) |

### Deep Link Flow

1. **User taps "Push" button** on widget
2. Widget sends `PendingIntent` with `copypaws://push` URI
3. Android launches/resumes app with the Intent
4. `MainActivity.handleIntent()` parses the URI
5. MainActivity sends action via MethodChannel(`widget_channel`)
6. `WidgetService.registerBackgroundCallback()` receives the action
7. Callback invokes `HomeScreen._handleWidgetAction()`
8. Action handler calls appropriate method (`_handlePushToHub()` or `_handleRefresh()`)

## Widget Updates

The widget automatically updates in these scenarios:

1. **New clip arrives from hub** → `SyncService` calls `WidgetService.updateWidget()`
2. **User pushes clipboard** → Widget shows the pushed content
3. **App is opened** → Widget syncs with latest clipboard data

### Update Mechanism

```dart
// In SyncService
_widgetService.updateWidget(_incomingClips);

// WidgetService saves data to SharedPreferences
await HomeWidget.saveWidgetData<String>('clip_0_content', clip.content);

// WidgetService triggers widget refresh
await HomeWidget.updateWidget(androidName: 'CopyPawsWidgetProvider');

// Android widget provider reads from SharedPreferences
val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
val content = prefs.getString("clip_0_content", "No clips yet")
```

## Customization

### Widget Layout

Edit `android/app/src/main/res/layout/widget_layout.xml` to customize:
- Widget colors
- Text sizes
- Layout structure
- Button styles

### Widget Appearance

Edit `android/app/src/main/res/drawable/widget_*.xml` for:
- Background colors/gradients
- Button backgrounds
- Border styles

### Widget Size

Edit `android/app/src/main/res/xml/widget_info.xml` to change:
- Minimum widget size
- Resize mode
- Update period

```xml
<appwidget-provider
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:updatePeriodMillis="0"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen" />
```

## Troubleshooting

### Widget Not Updating

**Problem:** Widget shows old data or "No clips yet"

**Solutions:**
1. Check if app is connected to hub
2. Force update by opening the app
3. Remove and re-add the widget
4. Check logcat for errors:
   ```bash
   adb logcat | grep -i "CopyPawsWidget\|widgetAction"
   ```

### Widget Buttons Not Working

**Problem:** Tapping Push/Pull does nothing

**Solutions:**
1. Verify app is installed and not force-stopped
2. Check deep link intent filter in AndroidManifest.xml
3. Test deep link manually:
   ```bash
   adb shell am start -W -a android.intent.action.VIEW \
     -d "copypaws://push" com.example.copypaws
   ```
4. Check MainActivity logs:
   ```bash
   adb logcat | grep "MainActivity"
   ```

### Widget Shows Empty

**Problem:** Widget displays blank or crashes

**Solutions:**
1. Verify widget layout XML is valid
2. Check if SharedPreferences are being written:
   ```bash
   adb shell run-as com.example.copypaws \
     cat shared_prefs/FlutterSharedPreferences.xml
   ```
3. Look for widget provider errors:
   ```bash
   adb logcat | grep "CopyPawsWidgetProvider"
   ```

### Deep Link Not Working

**Problem:** Widget tap doesn't open app or trigger action

**Solutions:**
1. Verify intent filter in AndroidManifest.xml includes all necessary categories
2. Check if app's launch mode conflicts (should be `singleTop`)
3. Test with explicit Intent:
   ```bash
   adb shell am start -n com.example.copypaws/.MainActivity \
     -d "copypaws://push"
   ```

## Testing

### Manual Testing Checklist

- [ ] Widget installation
  - [ ] Can add widget to home screen
  - [ ] Widget displays correctly
  - [ ] Widget shows "No clips yet" initially

- [ ] Widget display
  - [ ] Shows top 3 most recent clips
  - [ ] Truncates long text properly
  - [ ] Updates when new clip arrives

- [ ] Push button
  - [ ] App opens when tapped (if closed)
  - [ ] Clipboard is pushed to hub
  - [ ] Widget updates with pushed content

- [ ] Pull button
  - [ ] App opens when tapped (if closed)
  - [ ] Latest clip is fetched from hub
  - [ ] Widget updates with pulled content

- [ ] Widget tap
  - [ ] Opens main app
  - [ ] Shows home screen

### ADB Testing Commands

```bash
# Test Push action
adb shell am start -W -a android.intent.action.VIEW \
  -d "copypaws://push" com.example.copypaws

# Test Pull action
adb shell am start -W -a android.intent.action.VIEW \
  -d "copypaws://pull" com.example.copypaws

# Test Open action
adb shell am start -W -a android.intent.action.VIEW \
  -d "copypaws://open" com.example.copypaws

# View widget logs
adb logcat | grep -E "CopyPawsWidget|widgetAction|MainActivity"

# Clear app data and test fresh install
adb shell pm clear com.example.copypaws
```

## Performance Considerations

### Battery Optimization

- Widget updates are triggered only when necessary (new clips, explicit push/pull)
- No polling mechanism (uses event-driven updates)
- `updatePeriodMillis` is set to 0 (no system-triggered updates)

### Memory Usage

- Widget only stores minimal data (top 3 clips)
- SharedPreferences used for data sharing (lightweight)
- No background services running

## Known Limitations

1. **Widget size:** Currently optimized for medium size, small size may truncate text
2. **Clip types:** Only text clips supported, images/files not shown in widget
3. **Update frequency:** Widget won't update when app is force-stopped
4. **Android version:** Requires Android 5.0+ (API 21+)

## Future Enhancements

Potential improvements for future versions:

- [ ] Support for image previews in widget
- [ ] Tappable individual clips to copy directly
- [ ] Widget configuration options (theme, size)
- [ ] Live Activity support for real-time updates
- [ ] Widget for different sizes (small, large, extra large)

---

**Last Updated:** 2026-01-06
**Version:** 1.0.0
