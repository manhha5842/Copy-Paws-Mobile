# CopyPaws Mobile

Ứng dụng **Flutter** đồng bộ clipboard với CopyPaws Desktop qua mạng local.

## 🚀 Quick Start

```bash
# Cài dependencies
flutter pub get

# Chạy app
flutter run

# Build Android
flutter build apk --release

# Build iOS
flutter build ios --release
```

## 📁 Cấu trúc

```
lib/
├── main.dart                  # Entry point
├── core/                      # Core functionality
│   ├── config/               # App configuration
│   ├── constants/            # Enums & constants
│   ├── models/               # Data models
│   ├── services/             # Core services
│   │   ├── websocket_service.dart    # WebSocket client
│   │   ├── connection_manager.dart   # Connection orchestration
│   │   ├── sync_service.dart         # Clipboard sync
│   │   ├── encryption_service.dart   # AES-256-GCM
│   │   ├── storage_service.dart      # Secure storage
│   │   ├── clipboard_service.dart    # System clipboard
│   │   ├── notification_service.dart # Push notifications
│   │   ├── discovery_service.dart    # mDNS discovery
│   │   └── widget_service.dart       # Home widget
│   ├── theme/                # UI theming
│   └── utils/                # Utilities
├── features/                  # Feature modules
│   ├── home/                 # Home screen + widgets
│   ├── scan/                 # QR scanning
│   ├── history/              # Clipboard history
│   └── settings/             # Settings page
├── providers/                 # State management
└── shared/                    # Shared widgets
```

## ✅ Tính năng hoàn thành

### Core Services
- ✅ **WebSocket Client** - Connect, disconnect, auto-reconnect
- ✅ **Connection Manager** - Pairing, handshake, device management
- ✅ **Sync Service** - Push/receive clipboard, encrypted
- ✅ **AES-256-GCM Encryption** - Full end-to-end encryption
- ✅ **Secure Storage** - Save hub info, shared secret
- ✅ **mDNS Discovery** - Auto-discover hubs on network
- ✅ **Notifications** - Local push notifications
- ✅ **Home Widget** - Quick actions widget

### Screens
- ✅ **Home Screen** - Connection status, push button, clips list
- ✅ **Scan QR Screen** - Camera, QR detection, parse copypaws:// URI
- ✅ **History Screen** - Clipboard history, copy, delete
- ✅ **Settings Screen** - Device name, connection info

### Protocol Support
- ✅ PAIRING_REQUEST / PAIRING_RESPONSE
- ✅ HANDSHAKE / HANDSHAKE_RESPONSE
- ✅ CLIP_PUSH / CLIP_BROADCAST
- ✅ GET_LATEST
- ✅ ENCRYPTED messages
- ✅ PING / PONG keep-alive

## 🔧 Workflow

### Pairing với Desktop
1. Mở CopyPaws Desktop
2. Vào Devices > Connect New Device
3. Mở Mobile app > Scan QR
4. Scan QR code
5. Kết nối tự động sau khi pair thành công

### Sync Clipboard
- **Push**: Nhấn "Push to Hub" để gửi clipboard lên Desktop
- **Receive**: Tự động nhận clips từ Desktop
- **Copy**: Tap để copy clip vào system clipboard

## 📊 Tiến độ

Xem chi tiết tại [PROGRESS.md](./PROGRESS.md)

| Module | Status |
|--------|--------|
| WebSocket Service | ✅ 100% |
| Connection Manager | ✅ 100% |
| Sync Service | ✅ 100% |
| Encryption | ✅ 100% |
| Storage | ✅ 100% |
| All Screens | ✅ 100% |

## 📋 TODO

- [ ] iOS background fetch
- [ ] Android foreground service
- [ ] Unit tests
- [ ] Integration tests
- [ ] Image clipboard support
- [ ] Search/filter history
- [ ] Auto-pair (không cần QR)

## 📦 Dependencies

| Package | Purpose |
|---------|---------|
| `web_socket_channel` | WebSocket client |
| `mobile_scanner` | QR code scanning |
| `flutter_secure_storage` | Secure storage |
| `bonsoir` | mDNS discovery |
| `flutter_local_notifications` | Push notifications |
| `pointycastle` | Encryption |
| `device_info_plus` | Device info |
| `uuid` | UUID generation |
| `home_widget` | Home widget |

## 🧪 Testing

### Test với Desktop
1. Chạy CopyPaws Desktop
2. Chạy Mobile app: `flutter run`
3. Scan QR để pair
4. Test push/receive clipboard

### Test với test-client
1. Chạy Desktop app
2. Mở `../test-client/index.html`
3. So sánh behavior với Mobile app

## 📝 Ghi chú

- App sử dụng feature-first architecture
- State management: ChangeNotifier (có thể thay BLoC/Riverpod)
- Theme đã cấu hình khớp với Desktop app
- Encryption key được lưu trong Secure Storage

---

Part of the **CopyPaws** ecosystem.
