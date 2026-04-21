import 'package:hive/hive.dart';

/// Settings for app-level biometric lock. Stored in the existing `settings`
/// Hive box to avoid spinning up another SQLite file for two boolean flags.
class BiometricSettings {
  static const _boxName = 'settings';
  static const _keyEnabled = 'biometric_enabled';
  static const _keyLastUnlock = 'biometric_last_unlock_ms';

  /// Idle period after which the lock re-engages when the app regains focus.
  static const Duration lockIdleAfter = Duration(minutes: 5);

  static Box get _box => Hive.box(_boxName);

  static bool isEnabled() => _box.get(_keyEnabled, defaultValue: false) == true;

  static Future<void> setEnabled(bool value) async {
    await _box.put(_keyEnabled, value);
  }

  static DateTime? lastUnlockAt() {
    final ms = _box.get(_keyLastUnlock);
    if (ms is int) return DateTime.fromMillisecondsSinceEpoch(ms);
    return null;
  }

  static Future<void> markUnlocked() async {
    await _box.put(
      _keyLastUnlock,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static bool shouldPromptNow() {
    if (!isEnabled()) return false;
    final last = lastUnlockAt();
    if (last == null) return true;
    return DateTime.now().difference(last) >= lockIdleAfter;
  }
}
