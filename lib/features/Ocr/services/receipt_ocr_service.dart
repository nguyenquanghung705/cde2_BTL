import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ParsedReceipt {
  final String rawText;

  /// Amount candidates extracted from the text (largest first).
  final List<double> amountCandidates;

  /// First date-looking token (yyyy-mm-dd / dd/mm/yyyy) if found.
  final DateTime? date;

  const ParsedReceipt({
    required this.rawText,
    required this.amountCandidates,
    this.date,
  });

  double? get bestAmount =>
      amountCandidates.isEmpty ? null : amountCandidates.first;
}

/// Lightweight receipt parser on top of ML Kit text recognition.
///
/// Extracts the printed text and applies simple regex heuristics to surface
/// the likely total amount and transaction date. Users confirm in the UI.
class ReceiptOcrService {
  final TextRecognizer _recognizer = TextRecognizer();

  Future<ParsedReceipt> recognize(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(inputImage);
    return parseText(result.text);
  }

  /// Public for unit tests.
  static ParsedReceipt parseText(String text) {
    final amounts = <double>{};
    final amountRe =
        RegExp(r'(\d{1,3}(?:[.,\s]\d{3})+|\d{4,})(?:[.,]\d{1,2})?');
    for (final m in amountRe.allMatches(text)) {
      final raw = m.group(0)!;
      final normalized = raw.replaceAll(RegExp(r'[.,\s]'), '');
      final parsed = double.tryParse(normalized);
      if (parsed != null && parsed >= 1000) amounts.add(parsed);
    }

    DateTime? date;
    final isoRe = RegExp(r'\b(20\d{2})-(\d{1,2})-(\d{1,2})\b');
    final dmyRe = RegExp(r'\b(\d{1,2})[/.-](\d{1,2})[/.-](20\d{2})\b');
    final isoMatch = isoRe.firstMatch(text);
    if (isoMatch != null) {
      date = DateTime(
        int.parse(isoMatch.group(1)!),
        int.parse(isoMatch.group(2)!),
        int.parse(isoMatch.group(3)!),
      );
    } else {
      final dmyMatch = dmyRe.firstMatch(text);
      if (dmyMatch != null) {
        date = DateTime(
          int.parse(dmyMatch.group(3)!),
          int.parse(dmyMatch.group(2)!),
          int.parse(dmyMatch.group(1)!),
        );
      }
    }

    final sorted = amounts.toList()..sort((a, b) => b.compareTo(a));
    return ParsedReceipt(
      rawText: text,
      amountCandidates: sorted,
      date: date,
    );
  }

  void dispose() {
    _recognizer.close();
  }
}
