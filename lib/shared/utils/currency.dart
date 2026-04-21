import 'package:intl/intl.dart';

/// Standard VND formatting used across the app.
///
/// Examples:
///   formatVnd(1500000)  -> "1.500.000 ₫"
///   formatVnd(1500000.75, decimals: 2) -> "1.500.000,75 ₫"
///   formatVndCompact(1500000)  -> "1,5tr ₫"
class CurrencyFormat {
  /// Vietnamese conventionally uses dot as thousand separator and comma as
  /// decimal separator, so we build an explicit locale pattern rather than
  /// relying on vi_VN which isn't consistently available on every platform.
  static final NumberFormat _vndInt = NumberFormat('#,##0', 'vi_VN');
  static final NumberFormat _vndDouble = NumberFormat('#,##0.00', 'vi_VN');

  static String vnd(num amount, {int decimals = 0}) {
    final fmt = decimals > 0 ? _vndDouble : _vndInt;
    return '${fmt.format(amount)} ₫';
  }

  /// Short form for dashboards (e.g. "1,5tr ₫", "125k ₫").
  static String vndCompact(num amount) {
    final a = amount.abs();
    String body;
    if (a >= 1000000000) {
      body = '${(amount / 1000000000).toStringAsFixed(1)}tỷ';
    } else if (a >= 1000000) {
      body = '${(amount / 1000000).toStringAsFixed(1)}tr';
    } else if (a >= 1000) {
      body = '${(amount / 1000).toStringAsFixed(0)}k';
    } else {
      body = amount.toStringAsFixed(0);
    }
    // Replace "." with "," for decimal separator per vi_VN convention.
    return '${body.replaceAll('.', ',')} ₫';
  }
}
