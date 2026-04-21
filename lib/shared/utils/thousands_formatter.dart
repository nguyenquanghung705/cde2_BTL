import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Helpers for displaying a VND amount with dot thousand separators.
///
/// Historically this module shipped an InputFormatter. That turned out to be
/// fragile on Flutter Web: Chrome can fire a second "input" event for a single
/// keystroke (especially with an IME like Vietnamese Telex active), which made
/// the live-reformatting InputFormatter occasionally commit a digit twice and
/// caused the caret to jump into unrelated positions.
///
/// The replacement is a much simpler two-layer approach:
///
/// 1. [TextField.inputFormatters] uses the stock
///    [FilteringTextInputFormatter.digitsOnly] — digits pass through as-is,
///    everything else is dropped. The engine never has to reconcile a formatter
///    that rewrites text under it, so IME duplication is gone.
///
/// 2. [attachVndFormatting] installs a [TextEditingController] listener that
///    re-inserts dot separators *after* the commit, preserving the caret
///    based on how many digits sit to the left of it. Because this runs at the
///    controller level (not the engine level), it never fights with the
///    keyboard.
class VndThousandsFormatter {
  VndThousandsFormatter._();

  static final RegExp _nonDigit = RegExp(r'\D');

  /// Dotted form of [raw] — "1500000" -> "1.500.000".
  /// Ignores any non-digit characters already in [raw].
  static String format(String raw) {
    final digits = raw.replaceAll(_nonDigit, '');
    if (digits.isEmpty) return '';
    final buf = StringBuffer();
    final len = digits.length;
    for (var i = 0; i < len; i++) {
      final fromEnd = len - i;
      buf.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write('.');
    }
    return buf.toString();
  }

  /// Parse "1.500.000" back to a double. Returns null for an empty string.
  static double? parse(String formatted) {
    final digits = formatted.replaceAll(_nonDigit, '');
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  /// Attach a listener that keeps [controller] displaying dot-separated VND
  /// as the user types. Returns a disposer — call it from `State.dispose`
  /// (or ignore if the controller itself is disposed there).
  static VoidCallback attach(TextEditingController controller) {
    // Guard against recursion: setting controller.value inside a listener
    // re-fires the listener. Re-entrancy is short-circuited by comparing
    // against the last text we wrote.
    String lastHandled = controller.text;

    void handler() {
      final raw = controller.text;
      if (raw == lastHandled) return;

      final digits = raw.replaceAll(_nonDigit, '');
      final formatted = digits.isEmpty ? '' : _formatDigits(digits);

      if (formatted == raw) {
        lastHandled = raw;
        return;
      }

      // Preserve caret by digit count left of it — never snap to the end,
      // which is what makes editing in the middle feel broken.
      final selection = controller.selection;
      final rawCursor = selection.baseOffset < 0
          ? raw.length
          : selection.baseOffset.clamp(0, raw.length);
      final digitsLeft =
          raw.substring(0, rawCursor).replaceAll(_nonDigit, '').length;

      var newCursor = formatted.length;
      var counted = 0;
      for (var i = 0; i < formatted.length; i++) {
        if (counted == digitsLeft) {
          newCursor = i;
          break;
        }
        if (formatted[i] != '.') counted++;
      }

      lastHandled = formatted;
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: newCursor),
        composing: TextRange.empty,
      );
    }

    controller.addListener(handler);
    return () => controller.removeListener(handler);
  }

  static String _formatDigits(String digits) {
    final buf = StringBuffer();
    final len = digits.length;
    for (var i = 0; i < len; i++) {
      final fromEnd = len - i;
      buf.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write('.');
    }
    return buf.toString();
  }
}

/// The one input formatter every VND field should stack: just digits,
/// nothing fancy. Dot insertion happens post-commit via
/// [VndThousandsFormatter.attach].
final List<TextInputFormatter> vndInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];
