import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLockSettings {
  const AppLockSettings({
    required this.enabled,
    this.biometricEnabled = false,
    this.lockAfter = 'Immediately',
  });

  const AppLockSettings.disabled()
    : enabled = false,
      biometricEnabled = false,
      lockAfter = 'Immediately';

  final bool enabled;
  final bool biometricEnabled;
  final String lockAfter;

  Duration get lockDelay => switch (lockAfter) {
    'After 1 minute' => const Duration(minutes: 1),
    'After 5 minutes' => const Duration(minutes: 5),
    _ => Duration.zero,
  };
}

/// Stores the device-only app lock in the platform's encrypted key store.
class AppLockService {
  AppLockService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _pinKey = 'app_lock_pin_v1';
  static const _biometricKey = 'app_lock_biometric_v1';
  static const _lockAfterKey = 'app_lock_after_v1';
  static const _validLockAfter = {
    'Immediately',
    'After 1 minute',
    'After 5 minutes',
  };

  final FlutterSecureStorage _storage;

  Future<AppLockSettings> read() async {
    try {
      final values = await Future.wait<String?>([
        _storage.read(key: _pinKey),
        _storage.read(key: _biometricKey),
        _storage.read(key: _lockAfterKey),
      ]);
      final pin = values[0];
      if (pin == null || !RegExp(r'^\d{4}$').hasMatch(pin)) {
        return const AppLockSettings.disabled();
      }
      final storedDelay = values[2];
      return AppLockSettings(
        enabled: true,
        biometricEnabled: values[1] == 'true',
        lockAfter: _validLockAfter.contains(storedDelay)
            ? storedDelay!
            : 'Immediately',
      );
    } catch (_) {
      // If the platform key store is unavailable, never trap the user behind
      // a lock that cannot be verified.
      return const AppLockSettings.disabled();
    }
  }

  Future<void> enable(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError.value(pin, 'pin', 'Enter a 4-digit PIN.');
    }
    await _storage.write(key: _biometricKey, value: 'false');
    await _storage.write(key: _lockAfterKey, value: 'Immediately');
    // Write the PIN last because its presence is the enabled-state marker.
    await _storage.write(key: _pinKey, value: pin);
  }

  Future<void> disable() async {
    await Future.wait<void>([
      _storage.delete(key: _pinKey),
      _storage.delete(key: _biometricKey),
      _storage.delete(key: _lockAfterKey),
    ]);
  }

  Future<bool> verifyPin(String candidate) async {
    try {
      final stored = await _storage.read(key: _pinKey);
      if (stored == null || stored.length != candidate.length) return false;
      var difference = 0;
      for (var index = 0; index < stored.length; index++) {
        difference |= stored.codeUnitAt(index) ^ candidate.codeUnitAt(index);
      }
      return difference == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> replacePin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError.value(pin, 'pin', 'Enter a 4-digit PIN.');
    }
    await _storage.write(key: _pinKey, value: pin);
  }

  Future<void> setBiometricEnabled(bool enabled) =>
      _storage.write(key: _biometricKey, value: enabled.toString());

  Future<void> setLockAfter(String value) async {
    if (!_validLockAfter.contains(value)) {
      throw ArgumentError.value(value, 'value', 'Unsupported lock delay.');
    }
    await _storage.write(key: _lockAfterKey, value: value);
  }
}
