import 'package:financy_ui/features/Ocr/services/receipt_ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts largest amount as bestAmount', () {
    final r = ReceiptOcrService.parseText('''
      Cafe sáng     35.000
      Bánh mì        15.000
      Tổng cộng    150.000
    ''');
    expect(r.bestAmount, 150000);
    expect(r.amountCandidates.first, 150000);
  });

  test('parses ISO date', () {
    final r = ReceiptOcrService.parseText('Date: 2026-04-20\nTotal: 99.999');
    expect(r.date, DateTime(2026, 4, 20));
  });

  test('parses dd/mm/yyyy date', () {
    final r = ReceiptOcrService.parseText('Ngày 20/04/2026\n100.000');
    expect(r.date, DateTime(2026, 4, 20));
  });

  test('ignores small numbers (under 1000)', () {
    final r = ReceiptOcrService.parseText('SL: 3 x 500 = 999');
    expect(r.bestAmount, isNull);
  });

  test('rawText retained verbatim', () {
    const text = 'ABCD 123\n50.000';
    final r = ReceiptOcrService.parseText(text);
    expect(r.rawText, text);
  });

  test('no date returns null date', () {
    final r = ReceiptOcrService.parseText('No dates here — 10.000');
    expect(r.date, isNull);
    expect(r.bestAmount, 10000);
  });
}
