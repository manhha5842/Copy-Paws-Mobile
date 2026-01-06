/// App configuration constants and initialization
class AppConfig {
  AppConfig._();

  // App Info
  static const String appName = 'CopyPaws';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // Network
  static const int wsPort = 9876;
  static const String mdnsServiceType = '_clipboardhub._tcp';
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const int maxReconnectAttempts = 5;

  // Encryption
  static const int keySize = 32; // 256 bits for AES-256
  static const int ivSize = 12; // 96 bits for GCM
  static const int tagSize = 16; // 128 bits auth tag

  // Limits
  static const int maxPayloadSize = 2 * 1024 * 1024; // 2MB
  static const int clipPreviewLength = 100;
  static const int maxHistoryItems = 100;

  /// Initialize app configuration
  static Future<void> initialize() async {
    // TODO: Load saved preferences
    // TODO: Initialize secure storage
    // TODO: Initialize logging
  }
}
