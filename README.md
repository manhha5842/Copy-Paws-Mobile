# CopyPaws Mobile

CopyPaws Mobile is a Flutter companion app for CopyPaws Desktop that syncs clipboard content over your local network.

The app is designed around a local-first workflow:
- pair with the desktop hub using a QR code
- connect over LAN with WebSocket
- encrypt clipboard payloads with AES-256-GCM
- keep a local clipboard history on the device

CopyPaws Mobile is meant to make copy/paste between phone and desktop feel fast, private, and low-friction without relying on a cloud relay.

## Highlights

- LAN-based clipboard sync between desktop and mobile
- QR pairing for first-time setup
- Auto-connect to the last paired hub
- AES-256-GCM end-to-end payload encryption
- Local clipboard history with SQLite
- Local notifications for incoming clips
- Android foreground service for background connectivity
- Android home widget for quick push/pull actions

## Current Status

- Android is the primary target and has the most complete feature set
- iOS shares the Flutter codebase, but background and widget support still need more work
- Text clipboard sync is the main supported flow today
- Rich clipboard flows such as images and files are still being refined across platforms

## Core Features

### Connection

- mDNS discovery for finding a desktop hub on the same network
- QR-based pairing
- Handshake flow for trusted reconnects
- Auto-reconnect when returning to the app or restoring a saved session

### Clipboard Sync

- Push the current mobile clipboard to desktop
- Receive new clips from the desktop hub in near real time
- Copy items back from Incoming Clips or History
- Store clip metadata locally for history and widget updates

### Android Experience

- Foreground service to keep the connection alive while the app is backgrounded
- Notification support for newly received clips
- Home widget shortcuts for push and pull actions
- Settings helpers for notification and battery optimization permissions

## Tech Stack

- Flutter
- `web_socket_channel` for WebSocket communication
- `bonsoir` for mDNS discovery
- `pointycastle` for AES-256-GCM encryption
- `flutter_secure_storage` for secrets
- `shared_preferences` for lightweight settings and shared state
- `sqflite` for clipboard history
- `flutter_local_notifications` for local notifications
- `flutter_background_service` for Android background execution
- `home_widget` for Android widgets

## Project Structure

```text
lib/
|-- core/
|   |-- config/
|   |-- constants/
|   |-- models/
|   |-- services/
|   |-- theme/
|   `-- utils/
|-- features/
|   |-- history/
|   |-- home/
|   |-- scan/
|   `-- settings/
|-- providers/
|-- shared/
`-- main.dart
```

## Requirements

- Flutter 3.35+
- Dart 3.10+
- Android Studio or Xcode
- A running CopyPaws Desktop hub on the same LAN

## Getting Started

```bash
flutter pub get
flutter run
```

### Build Android

```bash
flutter build apk --release
```

### Build iOS

```bash
flutter build ios --release
```

## Typical Flow

### 1. Pair with desktop

1. Open CopyPaws Desktop
2. Show the pairing QR code on desktop
3. Open CopyPaws Mobile
4. Go to the scan screen and scan the QR code
5. The app stores the shared secret and connects to the hub

### 2. Sync clipboard content

- Mobile to desktop: copy content on your phone and tap `Push to Hub`
- Desktop to mobile: copy something on desktop and it appears in the app
- App to system clipboard: tap `Copy` from Incoming Clips or History

## Related Docs

- [Protocol Reference](./Architecture/PROTOCOL.md)
- [Overview](./OVERVIEW.md)
- [Progress Summary](./PROGRESS.md)
- [Roadmap / TODO](./TODO.md)
- [Android Widget Setup](./WIDGET_ANDROID_SETUP.md)
- [iOS Widget Setup](./WIDGET_IOS_SETUP.md)
- [Widget Test Guide](./WIDGET_TEST_GUIDE.md)

## Roadmap

- Improve image and file clipboard flows
- Make Android background sync more resilient across OEM devices
- Improve iOS background and widget support
- Add more unit and integration tests
- Expand setup and debugging documentation

## Notes

- This repository is the mobile companion app for CopyPaws Desktop and does not work as a standalone product without a desktop hub
- The current architecture is LAN-first and does not use Firebase or a cloud relay by default
- Background behavior may still vary depending on Android OEM restrictions and iOS platform limits

## License

No license has been declared in this repository yet.

---

Part of the CopyPaws ecosystem.
