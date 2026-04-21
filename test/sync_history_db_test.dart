import 'package:financy_ui/app/services/Local/sync_history_db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await SyncHistoryDb.instance.resetForTesting();
    await SyncHistoryDb.instance.initForTesting();
  });

  tearDown(() async {
    await SyncHistoryDb.instance.resetForTesting();
  });

  SyncHistoryEntry make({
    bool success = true,
    int durationMs = 500,
    int items = 3,
    int attempts = 1,
    DateTime? startedAt,
    String? err,
  }) =>
      SyncHistoryEntry(
        startedAt: startedAt ?? DateTime(2026, 4, 20),
        durationMs: durationMs,
        success: success,
        itemCount: items,
        attempts: attempts,
        errorMessage: err,
      );

  test('record + recent returns inserted row', () async {
    await SyncHistoryDb.instance.record(make());
    final list = await SyncHistoryDb.instance.recent();
    expect(list.length, 1);
    expect(list.first.success, isTrue);
    expect(list.first.itemCount, 3);
  });

  test('recent sorted by startedAt DESC', () async {
    await SyncHistoryDb.instance.record(
      make(startedAt: DateTime(2026, 1, 1)),
    );
    await SyncHistoryDb.instance.record(
      make(startedAt: DateTime(2026, 5, 1)),
    );
    await SyncHistoryDb.instance.record(
      make(startedAt: DateTime(2026, 3, 1)),
    );
    final list = await SyncHistoryDb.instance.recent();
    expect(
      list.map((e) => e.startedAt.month).toList(),
      [5, 3, 1],
    );
  });

  test('failure entries preserve error message', () async {
    await SyncHistoryDb.instance.record(
      make(success: false, err: 'timeout'),
    );
    final list = await SyncHistoryDb.instance.recent();
    expect(list.first.success, isFalse);
    expect(list.first.errorMessage, 'timeout');
  });

  test('clear removes all rows', () async {
    await SyncHistoryDb.instance.record(make());
    await SyncHistoryDb.instance.record(make());
    await SyncHistoryDb.instance.clear();
    expect(await SyncHistoryDb.instance.recent(), isEmpty);
  });

  test('recent respects limit argument', () async {
    for (var i = 0; i < 5; i++) {
      await SyncHistoryDb.instance
          .record(make(startedAt: DateTime(2026, 1, i + 1)));
    }
    final list = await SyncHistoryDb.instance.recent(limit: 2);
    expect(list.length, 2);
  });
}
