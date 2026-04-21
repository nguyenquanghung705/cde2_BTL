import 'package:hive/hive.dart';

/// Stores bank/e-wallet account numbers keyed by the MoneySource id.
///
/// Kept as a side-table (separate Hive box) so we don't have to regenerate
/// the MoneySource Hive adapter for a new HiveField. Call sites should
/// treat the number as opaque — masking for display happens here.
class AccountNumbersStore {
  static const _boxName = 'accountNumbers';

  static Box get _box => Hive.box(_boxName);

  static Future<void> ensureOpen() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static String? get(String? moneySourceId) {
    if (moneySourceId == null) return null;
    final v = _box.get(moneySourceId);
    return v is String && v.isNotEmpty ? v : null;
  }

  static Future<void> set(String moneySourceId, String? number) async {
    final trimmed = number?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _box.delete(moneySourceId);
    } else {
      await _box.put(moneySourceId, trimmed);
    }
  }

  /// Display-safe masked form: keeps first 4 and last 4 digits, e.g.
  /// "1234 •••• 5678". Returns null if not set.
  static String? masked(String? moneySourceId) {
    final raw = get(moneySourceId);
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'\s+'), '');
    if (digits.length <= 8) return digits;
    final first = digits.substring(0, 4);
    final last = digits.substring(digits.length - 4);
    return '$first •••• $last';
  }
}
