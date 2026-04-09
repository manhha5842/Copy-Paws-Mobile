/// Connection states for WebSocket
enum ConnectionState {
  disconnected,
  discovering,
  connecting,
  authenticating,
  connected,
  paused,
  error,
}

/// Extension methods for ConnectionState
extension ConnectionStateX on ConnectionState {
  static ConnectionState fromString(String? value) {
    switch (value) {
      case 'discovering':
        return ConnectionState.discovering;
      case 'connecting':
        return ConnectionState.connecting;
      case 'authenticating':
        return ConnectionState.authenticating;
      case 'connected':
        return ConnectionState.connected;
      case 'paused':
        return ConnectionState.paused;
      case 'error':
        return ConnectionState.error;
      case 'disconnected':
      default:
        return ConnectionState.disconnected;
    }
  }

  String get displayName {
    switch (this) {
      case ConnectionState.disconnected:
        return 'Disconnected';
      case ConnectionState.discovering:
        return 'Discovering...';
      case ConnectionState.connecting:
        return 'Connecting...';
      case ConnectionState.authenticating:
        return 'Authenticating...';
      case ConnectionState.connected:
        return 'Connected';
      case ConnectionState.paused:
        return 'Paused';
      case ConnectionState.error:
        return 'Error';
    }
  }

  bool get isActive => this == ConnectionState.connected;

  bool get isLoading =>
      this == ConnectionState.discovering ||
      this == ConnectionState.connecting ||
      this == ConnectionState.authenticating;
}
