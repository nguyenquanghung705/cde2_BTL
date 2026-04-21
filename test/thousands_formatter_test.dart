import 'package:financy_ui/shared/utils/thousands_formatter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('format / parse', () {
    test('format inserts dot thousand separators', () {
      expect(VndThousandsFormatter.format('1500000'), '1.500.000');
      expect(VndThousandsFormatter.format('100'), '100');
      expect(VndThousandsFormatter.format(''), '');
    });

    test('format drops non-digit characters', () {
      expect(VndThousandsFormatter.format('abc 1.234.567 xyz'), '1.234.567');
    });

    test('parse strips dots back to a double', () {
      expect(VndThousandsFormatter.parse('1.500.000'), 1500000);
      expect(VndThousandsFormatter.parse(''), isNull);
    });
  });

  group('attach — controller listener', () {
    test('simple digit-only input is dot-formatted after commit', () async {
      final controller = TextEditingController();
      final detach = VndThousandsFormatter.attach(controller);

      controller.text = '1500000';
      await Future.microtask(() {});
      expect(controller.text, '1.500.000');
      expect(controller.selection.baseOffset, 9);

      detach();
    });

    test('typing through the 4-digit boundary adds the first dot', () async {
      final controller = TextEditingController();
      final detach = VndThousandsFormatter.attach(controller);

      controller.text = '1234';
      await Future.microtask(() {});
      expect(controller.text, '1.234');
      expect(controller.selection.baseOffset, 5);

      detach();
    });

    test('attach preserves caret by digit count when editing in the middle',
        () async {
      final controller = TextEditingController(text: '1.500.000');
      final detach = VndThousandsFormatter.attach(controller);

      // Simulate the engine delivering "1.5x00.000" — user typed an "x"
      // (which will be ignored by the filter in practice, but this exercises
      // the listener path directly with a non-digit character).
      controller.value = const TextEditingValue(
        text: '12.500.000',
        selection: TextSelection.collapsed(offset: 2),
      );
      await Future.microtask(() {});
      expect(controller.text, '12.500.000');
      expect(controller.selection.baseOffset, 2);

      detach();
    });

    test('clearing the text is allowed', () async {
      final controller = TextEditingController(text: '1.500');
      final detach = VndThousandsFormatter.attach(controller);

      controller.text = '';
      await Future.microtask(() {});
      expect(controller.text, '');

      detach();
    });

    test('listener is idempotent — does not keep re-emitting', () async {
      final controller = TextEditingController();
      var emissionCount = 0;
      controller.addListener(() => emissionCount++);
      final detach = VndThousandsFormatter.attach(controller);

      controller.text = '1234';
      await Future.microtask(() {});
      // Expected sequence: user text change (+1) → formatter rewrites to
      // "1.234" (+1). Any further emission would be a re-entry bug.
      expect(emissionCount, 2);
      expect(controller.text, '1.234');

      detach();
    });
  });

  group('vndInputFormatters', () {
    test('filters out non-digit characters', () {
      final f = vndInputFormatters.single;
      final out = f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '1a2b3',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(out.text, '123');
    });
  });
}
