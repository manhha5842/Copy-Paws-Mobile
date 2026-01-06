# CopyPaws Mobile

Ứng dụng mobile đồng bộ clipboard với CopyPaws Desktop qua mạng local.

## Cấu trúc thư mục

```
lib/
├── main.dart                    # Entry point
├── core/                        # Core functionality
│   ├── config/                  # App configuration
│   │   └── app_config.dart
│   ├── constants/               # Constants & enums
│   │   ├── connection_state.dart
│   │   ├── message_types.dart
│   │   └── storage_keys.dart
│   ├── models/                  # Data models
│   │   ├── clipboard_item.dart
│   │   ├── device_info.dart
│   │   └── hub_info.dart
│   ├── services/                # Core services
│   │   ├── clipboard_service.dart
│   │   ├── discovery_service.dart
│   │   ├── encryption_service.dart
│   │   ├── notification_service.dart
│   │   ├── storage_service.dart
│   │   └── websocket_service.dart
│   ├── theme/                   # Theme configuration
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   └── app_theme.dart
│   ├── utils/                   # Utility functions
│   │   ├── helpers.dart
│   │   └── logger.dart
│   └── core.dart               # Core exports
├── features/                    # Feature modules
│   ├── home/                   # Home screen
│   │   ├── presentation/
│   │   │   └── screens/
│   │   │       └── home_screen.dart
│   │   ├── widgets/
│   │   │   ├── connection_status_card.dart
│   │   │   ├── incoming_clips_list.dart
│   │   │   ├── push_button.dart
│   │   │   └── quick_actions_row.dart
│   │   └── home.dart
│   ├── scan/                   # QR Scan screen
│   │   ├── presentation/
│   │   │   └── screens/
│   │   │       └── scan_qr_screen.dart
│   │   └── scan.dart
│   ├── history/                # History screen
│   │   ├── presentation/
│   │   │   └── screens/
│   │   │       └── history_screen.dart
│   │   └── history.dart
│   └── settings/               # Settings screen
│       ├── presentation/
│       │   └── screens/
│       │       └── settings_screen.dart
│       └── settings.dart
├── providers/                   # State management
│   ├── app_state.dart
│   └── providers.dart
└── shared/                      # Shared widgets
    ├── widgets/
    │   ├── app_bar_widget.dart
    │   ├── empty_state.dart
    │   ├── error_display.dart
    │   └── loading_overlay.dart
    └── shared.dart
```

## Tính năng chính

### Phase 1: Setup ✅
- [x] Cấu trúc project
- [x] Theme & styling
- [x] Navigation cơ bản
- [ ] Install dependencies (`flutter pub get`)

### Phase 2: Core Features (TODO)
- [ ] QR Code scanning
- [ ] WebSocket client
- [ ] Encryption (AES-256-GCM)
- [ ] Clipboard access

### Phase 3: UI/UX (TODO)
- [ ] Home screen hoàn thiện
- [ ] Scan QR screen với camera
- [ ] History screen với search/filter
- [ ] Settings screen hoàn thiện

### Phase 4: Background (TODO)
- [ ] iOS background fetch
- [ ] Android foreground service
- [ ] Push notifications

### Phase 5: Testing (TODO)
- [ ] Unit tests
- [ ] Integration tests
- [ ] E2E tests

## Cài đặt

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

## Dependencies chính

- **web_socket_channel**: WebSocket client
- **mobile_scanner**: QR code scanning
- **flutter_secure_storage**: Secure storage
- **bonsoir**: mDNS discovery
- **flutter_local_notifications**: Push notifications
- **pointycastle**: Encryption

## Ghi chú

- App sử dụng feature-first architecture
- State management sử dụng ChangeNotifier (có thể thay bằng BLoC/Riverpod)
- Các service đã setup sẵn placeholder, cần implement chi tiết
- Theme đã cấu hình khớp với desktop app
