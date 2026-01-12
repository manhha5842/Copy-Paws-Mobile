# CopyPaws Mobile - Overview

**Phiên bản:** 1.1  
**Trạng thái:** Production Ready  
**Mô hình:** Local-first, WebSocket P2P (LAN)  
**Platform:** iOS / Android (Flutter)

---

## Vai trò

Mobile App là **client** kết nối tới Desktop Hub để đồng bộ clipboard:

- **Receive:** Nhận clipboard từ Desktop realtime
- **Send:** Gửi clipboard từ điện thoại lên Desktop
- **Widget:** Quick actions từ Home screen
- **Background:** Duy trì kết nối khi minimize app

---

## Tính năng chính

### Discovery & Connection
- **mDNS Discovery:** Tự động tìm Desktop Hub trên LAN
- **QR Pairing:** Scan QR để pair lần đầu
- **Auto-connect:** Tự động kết nối khi vào cùng WiFi vớiHub đã pair

### Clipboard Sync
- **Push:** Gửi clipboard từ điện thoại lên Desktop
- **Pull:** Nhận clipboard từ Desktop
- **Incoming Clips:** Danh sách clips nhận được

### Widget
- **Small (2x2):** 2 nút Push/Pull
- **Medium (4x2):** List clips + action buttons

### Background Service (Android)
- Foreground service giữ kết nối
- Persistent notification hiển thị status
- Auto-reconnect khi mất kết nối

### Share Extension
- Gửi text từ bất kỳ app nào lên Desktop
- Không cần mở app chính

---

## Tech Stack

- **Framework:** Flutter
- **Networking:** `web_socket_channel`
- **Discovery:** `bonsoir`
- **Encryption:** `pointycastle` (AES-256-GCM)
- **Storage:** `sqflite`, `flutter_secure_storage`
- **Background:** `flutter_background_service`

---

## Platform Constraints

### Android
- Android 10+: Clipboard access hạn chế khi background
- Foreground Service cần `FOREGROUND_SERVICE_DATA_SYNC` permission

### iOS
- iOS 14+: Clipboard paste có popup warning
- Background fetch có thời gian giới hạn
- Widget mở app qua deep-link

---

## Connection States

| State | Mô tả |
|-------|-------|
| `DISCONNECTED` | Chưa kết nối |
| `DISCOVERING` | Đang tìm Hub |
| `CONNECTING` | Đang kết nối WebSocket |
| `AUTHENTICATING` | Đang handshake |
| `CONNECTED` | Đã kết nối |
| `PAUSED` | User tạm dừng |
| `ERROR` | Lỗi kết nối |

---

## User Flow

1. **First Time:**
   - Mở app → Scan QR từ Desktop
   - Store shared_secret trong Keystore
   - Connected ✓

2. **Subsequent:**
   - Mở app → Auto-discover → Auto-connect
   - Không cần QR lại

3. **Send Clipboard:**
   - Copy text → Bấm "Push to Hub"
   - Hoặc Share Sheet → CopyPaws

4. **Receive Clipboard:**
   - Desktop copy → App hiện clip mới
   - Bấm "Copy" để ghi vào clipboard

---

## Roadmap v2+

- Image/File clipboard support
- iOS Share Extension
- iOS Widget improvements
- Cloud relay support
