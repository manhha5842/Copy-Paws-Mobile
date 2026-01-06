import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../utils/logger.dart';

/// Encryption service for AES-256-GCM encryption/decryption
/// Compatible with desktop protocol
class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  static const int keySize = 32; // 256 bits
  static const int ivSize = 12; // 96 bits (standard for GCM)
  static const int tagSize = 16; // 128 bits

  // Current encryption key
  Uint8List? _key;

  /// Set encryption key from shared secret (raw bytes)
  void setKeyBytes(Uint8List key) {
    if (key.length != keySize) {
      throw ArgumentError('Key must be $keySize bytes (got ${key.length})');
    }
    _key = Uint8List.fromList(key);
    AppLogger.info('Encryption key set (${key.length} bytes)');
  }

  /// Set encryption key from base64 encoded string
  void setKeyFromBase64(String base64Key) {
    final key = base64Decode(base64Key);
    setKeyBytes(key);
  }

  /// Set encryption key from hex string
  void setKeyFromHex(String hexKey) {
    final key = _hexToBytes(hexKey);
    setKeyBytes(key);
  }

  /// Derive key from shared secret using SHA-256
  /// This matches the desktop's key derivation
  void deriveKeyFromSecret(String sharedSecret) {
    final secretBytes = utf8.encode(sharedSecret);
    final digest = SHA256Digest();
    final key = Uint8List(digest.digestSize);
    digest.update(secretBytes, 0, secretBytes.length);
    digest.doFinal(key, 0);
    setKeyBytes(key.sublist(0, keySize));
  }

  /// Check if key is available
  bool get hasKey => _key != null;

  /// Generate random IV
  Uint8List generateIV() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(ivSize, (_) => random.nextInt(256)),
    );
  }

  /// Encrypt plaintext using AES-256-GCM
  EncryptedData encrypt(String plaintext) {
    if (_key == null) {
      throw StateError('Encryption key not set');
    }

    final iv = generateIV();
    final plaintextBytes = utf8.encode(plaintext);

    // Setup AES-GCM cipher
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(_key!),
      tagSize * 8, // tag length in bits
      iv,
      Uint8List(0), // no additional authenticated data
    );
    cipher.init(true, params); // true = encrypt

    // Encrypt
    final ciphertext = Uint8List(plaintextBytes.length + tagSize);
    final len = cipher.processBytes(
      plaintextBytes,
      0,
      plaintextBytes.length,
      ciphertext,
      0,
    );
    cipher.doFinal(ciphertext, len);

    AppLogger.debug(
      'Encrypted ${plaintextBytes.length} bytes → ${ciphertext.length} bytes',
    );

    return EncryptedData(
      ciphertext: base64Encode(ciphertext),
      iv: base64Encode(iv),
    );
  }

  /// Decrypt ciphertext using AES-256-GCM
  String decrypt(String encryptedPayloadBase64, String ivBase64) {
    if (_key == null) {
      throw StateError('Encryption key not set');
    }

    final ciphertext = base64Decode(encryptedPayloadBase64);
    final iv = base64Decode(ivBase64);

    if (iv.length != ivSize) {
      throw ArgumentError('Invalid IV length: ${iv.length} (expected $ivSize)');
    }

    // Setup AES-GCM cipher
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(_key!),
      tagSize * 8,
      iv,
      Uint8List(0),
    );
    cipher.init(false, params); // false = decrypt

    // Decrypt
    final plaintext = Uint8List(ciphertext.length - tagSize);
    final len = cipher.processBytes(
      ciphertext,
      0,
      ciphertext.length,
      plaintext,
      0,
    );
    cipher.doFinal(plaintext, len);

    final result = utf8.decode(plaintext);
    AppLogger.debug(
      'Decrypted ${ciphertext.length} bytes → ${plaintext.length} bytes',
    );

    return result;
  }

  /// Try to decrypt, returns null on failure
  String? tryDecrypt(String encryptedPayloadBase64, String ivBase64) {
    try {
      return decrypt(encryptedPayloadBase64, ivBase64);
    } catch (e) {
      AppLogger.error('Decryption failed', error: e);
      return null;
    }
  }

  /// Clear encryption key
  void clearKey() {
    if (_key != null) {
      // Zero out key bytes for security
      for (var i = 0; i < _key!.length; i++) {
        _key![i] = 0;
      }
      _key = null;
      AppLogger.info('Encryption key cleared');
    }
  }

  /// Convert hex string to bytes
  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}

/// Encrypted data container
class EncryptedData {
  final String ciphertext; // Base64 encoded
  final String iv; // Base64 encoded

  EncryptedData({required this.ciphertext, required this.iv});

  Map<String, dynamic> toJson() {
    return {'payload_encrypted': ciphertext, 'iv': iv};
  }

  @override
  String toString() =>
      'EncryptedData(ciphertext: ${ciphertext.length} chars, iv: ${iv.length} chars)';
}
