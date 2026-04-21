import 'package:financy_ui/app/services/Local/export_history_db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await ExportHistoryDb.instance.resetForTesting();
    await ExportHistoryDb.instance.initForTesting();
  });

  tearDown(() async {
    await ExportHistoryDb.instance.resetForTesting();
  });

  ExportHistoryEntry make({
    String path = '/tmp/a.csv',
    int rowCount = 3,
    DateTime? at,
  }) =>
      ExportHistoryEntry(
        filePath: path,
        exportedAt: at ?? DateTime(2026, 4, 20),
        fromDate: DateTime(2026, 4, 1),
        toDate: DateTime(2026, 4, 30),
        rowCount: rowCount,
      );

  test('record + recent returns DESC', () async {
    await ExportHistoryDb.instance
        .record(make(path: '/a', at: DateTime(2026, 1, 1)));
    await ExportHistoryDb.instance
        .record(make(path: '/b', at: DateTime(2026, 3, 1)));
    await ExportHistoryDb.instance
        .record(make(path: '/c', at: DateTime(2026, 2, 1)));
    final list = await ExportHistoryDb.instance.recent();
    expect(list.map((e) => e.filePath).toList(), ['/b', '/c', '/a']);
  });

  test('clear removes all entries', () async {
    await ExportHistoryDb.instance.record(make());
    await ExportHistoryDb.instance.clear();
    expect(await ExportHistoryDb.instance.recent(), isEmpty);
  });
}
