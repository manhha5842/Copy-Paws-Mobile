## CopyPaws Mobile - Hướng dẫn chạy ứng dụng

### Yêu cầu
- **Flutter SDK**: >= 3.10.4
- **Dart SDK**: >= 3.10.4  
- **Android Studio** hoặc **Xcode** (cho iOS)
- **Thiết bị**: Android Emulator, iOS Simulator, hoặc thiết bị thật

### Bước 1: Cài đặt Dependencies
```bash
cd m:\Project\CopyPaws\Mobile
flutter pub get
```

### Bước 2: Kiểm tra thiết bị
```bash
# Liệt kê các thiết bị đang kết nối
flutter devices
```

### Bước 3: Chạy ứng dụng

#### Chạy ở chế độ Debug (khuyến nghị cho phát triển)
```bash
flutter run
```

#### Chạy trên thiết bị cụ thể
```bash
# Chạy trên Android
flutter run -d android

# Chạy trên iOS
flutter run -d ios

# Chạy trên một thiết bị cụ thể (thay <device_id>)
flutter run -d <device_id>
```

#### Chạy với Hot Reload
Sau khi app đã chạy, bạn có thể:
- Nhấn `r` để reload
- Nhấn `R` để restart hoàn toàn
- Nhấn `q` để thoát

### Bước 4: Build để Release (tuỳ chọn)

#### Android APK
```bash
flutter build apk --release
# File sẽ được tạo tại: build/app/outputs/flutter-apk/app-release.apk
```

#### Android App Bundle (khuyến nghị cho Play Store)
```bash
flutter build appbundle --release
# File sẽ được tạo tại: build/app/outputs/bundle/release/app-release.aab
```

#### iOS
```bash
flutter build ios --release
# Sau đó mở Xcode để archive và export
```

### Lưu ý quan trọng

1. **Quyền ứng dụng**:
   - Camera (để quét QR code)
   - Notification (để nhận thông báo clip mới)
   - Network (để kết nối với Desktop Hub)

2. **Cấu hình mạng**:
   - Điện thoại và máy tính phải cùng một mạng Wi-Fi
   - Firewall trên máy tính không chặn port 9876
   - Wi-Fi network phải ở chế độ "Private" (không phải Public)

3. **Khắc phục lỗi thường gặp**:
   - Nếu gặp lỗi build, thử: `flutter clean && flutter pub get`
   - Nếu không quét được QR: Kiểm tra quyền camera
   - Nếu không kết nối được: Kiểm tra cùng mạng và firewall

### Kiểm tra code
```bash
# Analyze code để phát hiện lỗi
flutter analyze

# Chạy tests
flutter test
```

### Debug
```bash
# Chạy với verbose logging
flutter run -v

# Xem logs realtime
flutter logs
```
