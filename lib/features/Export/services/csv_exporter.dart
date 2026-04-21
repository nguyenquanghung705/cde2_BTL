import 'dart:io' show File, Platform;

import 'package:financy_ui/app/services/Local/activity_logger.dart';
import 'package:financy_ui/app/services/Local/export_history_db.dart';
import 'package:financy_ui/features/transactions/models/transactionsModels.dart';
import 'package:path_provider/path_provider.dart';

class CsvExportResult {
  final String filePath;
  final int rowCount;
  const CsvExportResult(this.filePath, this.rowCount);
}

class CsvExporter {
  /// Writes [transactions] within [from]..[to] (inclusive) to a CSV file.
  Future<CsvExportResult> export({
    required List<Transactionsmodels> transactions,
    required DateTime from,
    required DateTime to,
  }) async {
    final filtered = transactions.where((t) {
      final d = t.transactionDate;
      if (d == null) return false;
      return !d.isBefore(from) && !d.isAfter(to);
    }).toList()
      ..sort((a, b) => (a.transactionDate ?? DateTime(0))
          .compareTo(b.transactionDate ?? DateTime(0)));

    final buffer = StringBuffer();
    buffer.writeln(
      'id,date,type,amount,category,account,note',
    );
    for (final t in filtered) {
      buffer.writeln([
        _esc(t.id),
        _esc(t.transactionDate?.toIso8601String() ?? ''),
        _esc(t.type.name),
        t.amount,
        _esc(t.categoriesId),
        _esc(t.accountId),
        _esc(t.note ?? ''),
      ].join(','));
    }

    final docDir = await getApplicationDocumentsDirectory();
    final sep = Platform.pathSeparator;
    final exportDir = '${docDir.path}${sep}exports';
    await File('$exportDir$sep.keep').create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final filePath = '$exportDir${sep}financy_$stamp.csv';
    await File(filePath).writeAsString(buffer.toString());

    await ExportHistoryDb.instance.record(ExportHistoryEntry(
      filePath: filePath,
      exportedAt: DateTime.now(),
      fromDate: from,
      toDate: to,
      rowCount: filtered.length,
    ));

    await ActivityLogger.log('export_csv', data: {
      'rows': filtered.length,
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    });
    return CsvExportResult(filePath, filtered.length);
  }

  static String _esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
