import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class PinCredentialStore {
  Future<bool> hasPin();
  Future<void> setPin(String pin);
  Future<bool> verifyPin(String pin);
  Future<void> clear();
}

class SecurePinCredentialStore implements PinCredentialStore {
  SecurePinCredentialStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const _saltKey = 'flow_pin_salt_v1';
  static const _hashKey = 'flow_pin_hash_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<bool> hasPin() async {
    try {
      return (await _storage.read(key: _saltKey))?.isNotEmpty == true &&
          (await _storage.read(key: _hashKey))?.isNotEmpty == true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw const FormatException('PIN must contain four digits.');
    }
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final hash = await compute(_derivePinHash, {
      'pin': pin,
      'salt': base64Encode(salt),
    });
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(key: _hashKey, value: hash);
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _saltKey);
    final expected = await _storage.read(key: _hashKey);
    if (salt == null || expected == null) return false;
    final actual = await compute(_derivePinHash, {'pin': pin, 'salt': salt});
    return _constantTimeEquals(actual.codeUnits, expected.codeUnits);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _hashKey);
  }
}

String _derivePinHash(Map<String, String> input) {
  final pin = utf8.encode(input['pin']!);
  final salt = base64Decode(input['salt']!);
  const iterations = 60000;
  final hmac = Hmac(sha256, pin);
  var block = Uint8List.fromList([...salt, 0, 0, 0, 1]);
  var current = Uint8List.fromList(hmac.convert(block).bytes);
  final output = Uint8List.fromList(current);
  for (var i = 1; i < iterations; i++) {
    current = Uint8List.fromList(hmac.convert(current).bytes);
    for (var j = 0; j < output.length; j++) {
      output[j] ^= current[j];
    }
  }
  return base64Encode(output);
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}

class MemoryPinCredentialStore implements PinCredentialStore {
  String? _pin;
  @override
  Future<bool> hasPin() async => _pin != null;
  @override
  Future<void> setPin(String pin) async => _pin = pin;
  @override
  Future<bool> verifyPin(String pin) async => _pin == pin;
  @override
  Future<void> clear() async => _pin = null;
}
