# CopyPaws Mobile - Detailed TODO

> **Goal**: Implement "Full Flow" optimized for Android.

## 1. Auto-Connect (High Priority) ✅ COMPLETED
- [x] **Discovery Service**:
  - ✅ Update mDNS parser to read TXT records (`server_id`).
- [x] **Connection Logic**:
  - ✅ Create `tryAutoConnect()`:
    1. Check if `saved_hub` exists.
    2. Start discovery.
    3. If discovered hub matches `saved_hub.server_id` -> Connect immediately.
  - ✅ Create `AutoConnectService` with full trigger support
- [x] **Triggers**:
  - ✅ `OnInit`: Try auto-connect on app launch.
  - ✅ `OnResume`: Try auto-connect when app comes to foreground.
  - ✅ `ConnectivityChanged`: Try auto-connect when WiFi connects.

## 2. Background Execution (Android) (High Priority)
- [x] **Foreground Service**:
  - ✅ Implement a persistent notification ("CopyPaws Service Running").
  - ✅ Ensure WebSocket stays connected even when app is swiped away (or reliable restart).
  - *Note*: Android 14+ has stricter rules for foreground services.
- [ ] **Background Sync**:
  - Listen for "Copy" events even in background (might need Accessibility Service or specialized permission on Android 10+... actually Android limits background clipboard access. We might only be able to Sync *to* Desktop in background easily, but reading *from* Desktop to Clipboard in background is restricted. Need to verify approach: maybe just notification triggers copy?).

## 3. Rich Clipboard Support (Medium Priority)
- [ ] **Images**:
  - Handle `content_type: image` messages.
  - Save received image to Gallery or Clipboard? (Android clipboard supports images).
  - Send Share Intent images to Desktop.

## 4. UI/UX Polish ✅ COMPLETED
- [x] **Status Indicator**: 
  - ✅ Clearer "Connecting...", "Connected", "Offline" states in Home.
  - ✅ Pulse animation for connecting states.
  - ✅ Glow effect for connected state.
  - ✅ Helpful hints for disconnected/error states.
- [x] **Notifications**:
  - ✅ "Received Clip from Desktop" -> Tap to copy/view.
  - ✅ Action buttons (Copy/View) in notification.
  - ✅ BigTextStyle for better content preview.

---

## Implementation Summary (2026-01-13)

### Added/Modified Files:
1. `lib/core/services/auto_connect_service.dart` - **NEW** Auto-connect with WiFi trigger
2. `lib/core/services/notification_service.dart` - Enhanced with action buttons
3. `lib/features/home/widgets/connection_status_card.dart` - Pulse animation & better UI
4. `lib/features/home/presentation/screens/home_screen.dart` - Integrated AutoConnectService
5. `pubspec.yaml` - Added `connectivity_plus` package

