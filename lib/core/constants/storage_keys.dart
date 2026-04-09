/// Storage keys for secure and local storage
class StorageKeys {
  StorageKeys._();

  // Secure storage keys (Keychain/Keystore)
  static const String sharedSecret = 'shared_secret';
  static const String pairingToken = 'pairing_token';
  static const String sessionKey = 'session_key';

  // Local storage keys
  static const String deviceId = 'device_id';
  static const String deviceName = 'device_name';
  static const String hubEndpoint = 'hub_endpoint';
  static const String hubName = 'hub_name';
  static const String hubId = 'hub_id';
  static const String lastConnectedIp = 'last_connected_ip';
  static const String lastConnectedPort = 'last_connected_port';

  // Settings
  static const String themeMode = 'theme_mode';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String autoConnect = 'auto_connect';
  static const String syncEnabled = 'sync_enabled';
  static const String autoCopyIncomingForeground =
      'auto_copy_incoming_foreground';
  static const String showPreview = 'show_preview';
  static const String lastAutoCopiedClipId = 'last_auto_copied_clip_id';
  static const String backgroundConnectionState = 'background_connection_state';
  static const String backgroundHubName = 'background_hub_name';
  static const String backgroundHubEndpoint = 'background_hub_endpoint';
  static const String backgroundIsConnected = 'background_is_connected';

  // Cache
  static const String clipHistoryCache = 'clip_history_cache';
  static const String latestClipCache = 'latest_clip_cache';
}
