import 'package:financy_ui/app/services/Local/activity_log_db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await ActivityLogDb.instance.resetForTesting();
    await ActivityLogDb.instance.initForTesting();
  });

  tearDown(() async {
    await ActivityLogDb.instance.resetForTesting();
  });

  ActivityEntry make({
    String event = 'nav_push',
    String? route = '/budget',
    Map<String, Object?>? data,
    DateTime? at,
  }) =>
      ActivityEntry(
        timestamp: at ?? DateTime(2026, 4, 20, 11, 23),
        event: event,
        route: route,
        data: data,
      );

  test('record + recent returns inserted entry', () async {
    await ActivityLogDb.instance.record(make(data: {'x': 1}));
    final list = await ActivityLogDb.instance.recent();
    expect(list.length, 1);
    expect(list.first.event, 'nav_push');
    expect(list.first.route, '/budget');
    expect(list.first.data, {'x': 1});
  });

  test('recent is DESC by timestamp', () async {
    await ActivityLogDb.instance
        .record(make(event: 'a', at: DateTime(2026, 1, 1)));
    await ActivityLogDb.instance
        .record(make(event: 'b', at: DateTime(2026, 3, 1)));
    await ActivityLogDb.instance
        .record(make(event: 'c', at: DateTime(2026, 2, 1)));
    final list = await ActivityLogDb.instance.recent();
    expect(list.map((e) => e.event).toList(), ['b', 'c', 'a']);
  });

  test('count reflects stored rows', () async {
    expect(await ActivityLogDb.instance.count(), 0);
    await ActivityLogDb.instance.record(make());
    await ActivityLogDb.instance.record(make());
    expect(await ActivityLogDb.instance.count(), 2);
  });

  test('clear removes all entries', () async {
    await ActivityLogDb.instance.record(make());
    await ActivityLogDb.instance.clear();
    expect(await ActivityLogDb.instance.count(), 0);
  });

  test('data JSON round-trips nested values', () async {
    await ActivityLogDb.instance.record(make(data: {
      'amount': 1500,
      'note': 'lương',
      'nested': {'a': true},
    }));
    final e = (await ActivityLogDb.instance.recent()).first;
    expect(e.data!['amount'], 1500);
    expect(e.data!['nested'], {'a': true});
  });
}
