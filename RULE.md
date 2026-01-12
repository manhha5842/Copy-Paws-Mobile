# CopyPaws Mobile - Coding Rules

## General

1. **Language:** Vietnamese comments OK, code/variables in English
2. **No print() in production:** Use `AppLogger`
3. **Error handling:** Always catch and log errors

---

## Dart/Flutter

### Style
- Follow Dart style guide
- `lowerCamelCase` for variables/functions
- `UpperCamelCase` for classes/types
- `snake_case` for file names

### Architecture
- Feature-based folder structure
- Services in `core/services/`
- Models in `core/models/`
- Screens in `features/[feature]/presentation/screens/`

### State Management
```dart
// Good - explicit state
class ConnectionManager {
  final _stateController = StreamController<ConnectionState>.broadcast();
  Stream<ConnectionState> get stateStream => _stateController.stream;
}

// Bad - implicit state
class ConnectionManager {
  ConnectionState state; // Hard to observe changes
}
```

### Error Handling
```dart
// Good
try {
  await riskyOperation();
} catch (e, stack) {
  AppLogger.error('Operation failed', error: e, stackTrace: stack);
  rethrow;
}

// Bad
try {
  await riskyOperation();
} catch (e) {
  // Silent fail - never do this
}
```

### Async
- Prefer `async/await` over `.then()`
- Always handle stream subscriptions
- Cancel subscriptions in `dispose()`

---

## Platform-Specific: Android

### Permissions
- Request at runtime, not just manifest
- Handle permission denied gracefully

### Foreground Service
- Must have notification
- Use `FOREGROUND_SERVICE_DATA_SYNC` type
- Handle service start/stop properly

### Widget
- Update via `home_widget` package
- Use `WorkManager` for periodic updates

---

## Platform-Specific: iOS

### Background
- Limited background execution
- Use Background Fetch sparingly
- Handle app resume correctly

### Clipboard
- iOS shows paste popup - inform user
- Use UIPasteboard carefully

---

## Encryption

```dart
// Good - use service
final encrypted = _encryptionService.encrypt(content);

// Bad - inline crypto
final cipher = GCMBlockCipher(AESEngine()); // Don't do this everywhere
```

---

## Logging

```dart
// Use AppLogger
AppLogger.info('Connected to hub');
AppLogger.debug('Received message: $type');
AppLogger.error('Connection failed', error: e);
AppLogger.ws('CLIP_PUSH sent', isIncoming: false);
```

---

## Documentation

1. Update `PROGRESS.md` when completing features
2. Update `TODO.md` when adding/removing tasks
3. Keep `Architecture/` in sync with Desktop and test-client
