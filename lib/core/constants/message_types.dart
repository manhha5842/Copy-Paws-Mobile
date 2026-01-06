/// WebSocket message types - compatible with desktop protocol
enum MessageType {
  // Outgoing (Client → Server)
  pairingRequest('PAIRING_REQUEST'),
  handshake('HANDSHAKE'),
  clipPush('CLIP_PUSH'),
  getLatest('GET_LATEST'),
  pong('PONG'),

  // Incoming (Server → Client)
  pairingResponse('PAIRING_RESPONSE'),
  handshakeResponse('HANDSHAKE_RESPONSE'), // Added: missing in original
  clipBroadcast('CLIP_BROADCAST'),
  encrypted('ENCRYPTED'),
  ping('PING'),
  error('ERROR');

  final String value;
  const MessageType(this.value);

  static MessageType? fromString(String value) {
    return MessageType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageType.error,
    );
  }
}

/// Device platform types
enum DevicePlatform {
  android('Android'),
  ios('iOS');

  final String value;
  const DevicePlatform(this.value);
}
