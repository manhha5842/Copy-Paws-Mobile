# Widget Installation & Testing Guide

## Vấn đề đã fix:
✅ **Missing strings.xml** - Đã tạo file chứa app_name và widget_description
✅ **Widget info configuration** - Cập nhật minWidth từ 140dp → 250dp
✅ **Preview layout** - Thêm previewLayout để widget hiển thị trong selector

## Cách thêm widget vào home screen:

### Bước 1: Mở app và kết nối
```
1. Mở CopyPaws app
2. Kết nối với Desktop hub (scan QR hoặc manual)
3. Đảm bảo có ít nhất 1 clip trong list
```

### Bước 2: Thêm widget
```
1. Long press trên home screen (giữ lâu màn hình chủ)
2. Chọn "Widgets" từ menu
3. Scroll xuống tìm "CopyPaws" hoặc "copypaws"
4. Long press widget icon và drag lên home screen
5. Release để place widget
```

### Bước 3: Kiểm tra widget display
Widget hiện ra với:
- **Trái**: Top 3 recent clips
- **Phải**: 2 nút Push và Pull

## Test widget functions:

### Test Push Button
```bash
# Hoặc test bằng tay: tap nút "Push" trên widget
adb shell am start -W -a android.intent.action.VIEW -d "copypaws://push" com.example.copypaws
```
Expected: App mở và push clipboard lên hub

### Test Pull Button
```bash
# Hoặc test bằng tay: tap nút "Pull" trên widget
adb shell am start -W -a android.intent.action.VIEW -d "copypaws://pull" com.example.copypaws
```
Expected: App mở và request latest clip từ hub

### Test Widget Click
```bash
# Hoặc test bằng tay: tap vào body của widget
adb shell am start -W -a android.intent.action.VIEW -d "copypaws://open" com.example.copypaws
```
Expected: App mở home screen

## Nếu widget vẫn blank:

### Option 1: Remove và re-add widget
```
1. Long press widget → Remove
2. Long press home screen → Widgets
3. Add lại CopyPaws widget
```

### Option 2: Force widget update
```bash
# Clear app data và reinstall
adb shell pm clear com.example.copypaws
flutter install --debug

# Sau đó add widget lại
```

### Option 3: Check logs
```bash
# Monitor widget logs
adb logcat | grep -i "CopyPawsWidget\|widgetAction"

# Check for errors
adb logcat | grep -i "error\|exception" | grep -i widget
```

## Widget sẽ update khi:
- ✅ New clip arrives từ hub
- ✅ User push clipboard lên hub
- ✅ User mở app
- ✅ User tap Pull button

## Notes:
- Widget cần ít nhất **250dp width** để hiển thị đầy đủ  
- Widget tốt nhất ở size medium (recommended: 4x2 grid cells)
- Widget sẽ show "No clips yet" nếu chưa có data
