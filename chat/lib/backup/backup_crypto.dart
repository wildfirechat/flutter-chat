
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class BackupCrypto {
  static const int SALT_LENGTH = 16;
  static const int IV_LENGTH = 16;
  static const int PBKDF2_ITERATIONS = 10000;
  static const int KEY_LENGTH = 32; // 256 bits

  static Map<String, dynamic> encryptData(Uint8List data, String password) {
    if (password.isEmpty) {
      throw ArgumentError("Password must not be empty");
    }

    // 1. Generate random Salt
    final salt = _generateRandomData(SALT_LENGTH);

    // 2. Derive key using PBKDF2-SHA256
    final key = _deriveKeyFromPassword(password, salt, PBKDF2_ITERATIONS);

    // 3. Generate random IV
    final iv = _generateRandomData(IV_LENGTH);

    // 4. Encrypt using AES-256-CBC
    final encryptedData = _encryptAES256CBC(data, key, iv);

    // 5. Return result
    return {
      'salt': base64Encode(salt),
      'iv': base64Encode(iv),
      'data': base64Encode(encryptedData),
      'iterations': PBKDF2_ITERATIONS,
    };
  }

  static Uint8List decryptData(Map<String, dynamic> encryptedData, String password) {
    if (password.isEmpty) {
      throw ArgumentError("Password must not be empty");
    }

    try {
      // 1. Extract salt, iv, data and iterations
      final salt = base64Decode(encryptedData['salt']);
      final iv = base64Decode(encryptedData['iv']);
      final data = base64Decode(encryptedData['data']);
      final iterations = encryptedData['iterations'] ?? PBKDF2_ITERATIONS;

      // 2. Derive key using PBKDF2-SHA256
      final key = _deriveKeyFromPassword(password, salt, iterations);

      // 3. Decrypt using AES-256-CBC
      return _decryptAES256CBC(data, key, iv);
    } catch (e) {
      throw Exception("Decryption failed: $e");
    }
  }

  static Uint8List _deriveKeyFromPassword(String password, Uint8List salt, int iterations) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, KEY_LENGTH));
    return pbkdf2.process(utf8.encode(password));
  }

  static Uint8List _encryptAES256CBC(Uint8List data, Uint8List key, Uint8List iv) {
    final cipher = PaddedBlockCipher("AES/CBC/PKCS7")
      ..init(true, PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(key), iv), null));
    return cipher.process(data);
  }

  static Uint8List _decryptAES256CBC(Uint8List encryptedData, Uint8List key, Uint8List iv) {
    final cipher = PaddedBlockCipher("AES/CBC/PKCS7")
      ..init(false, PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(key), iv), null));
    return cipher.process(encryptedData);
  }

  static Uint8List _generateRandomData(int length) {
    final random = Random.secure();
    final data = Uint8List(length);
    for (int i = 0; i < length; i++) {
      data[i] = random.nextInt(256);
    }
    return data;
  }

  static bool verifyPassword(Map<String, dynamic> encryptedData, String password) {
    try {
      decryptData(encryptedData, password);
      return true;
    } catch (e) {
      return false;
    }
  }
}
