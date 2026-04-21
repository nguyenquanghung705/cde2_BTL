import 'package:financy_ui/shared/utils/statistics_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats thousands with dot separator', () {
    expect(StatisticsUtils.formatAmount(1500000), '1.500.000');
    expect(StatisticsUtils.formatAmount(1000), '1.000');
    expect(StatisticsUtils.formatAmount(999), '999');
  });

  test('no K / M compaction', () {
    final s = StatisticsUtils.formatAmount(5500000);
    expect(s.contains('M'), isFalse);
    expect(s.contains('K'), isFalse);
    expect(s, '5.500.000');
  });

  test('handles zero', () {
    expect(StatisticsUtils.formatAmount(0), '0');
  });

  test('handles negative amounts', () {
    expect(StatisticsUtils.formatAmount(-1500000), '-1.500.000');
  });

  test('rounds to whole VND (no decimals)', () {
    expect(StatisticsUtils.formatAmount(1234.56), '1.235');
  });
}
