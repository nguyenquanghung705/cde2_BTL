import 'package:financy_ui/app/services/Local/recurring_db.dart';
import 'package:financy_ui/features/Recurring/services/recurring_engine.dart';
import 'package:financy_ui/features/transactions/models/transactionsModels.dart';
import 'package:financy_ui/features/transactions/repo/transactionsRepo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test double: in-memory transactions store, no Hive.
class _FakeTxRepo implements TransactionsRepo {
  final List<Transactionsmodels> saved = [];

  @override
  Future<void> saveToLocal(Transactionsmodels transaction) async {
    saved.add(transaction);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    await RecurringDb.instance.resetForTesting();
    await RecurringDb.instance.initForTesting();
  });

  tearDown(() async {
    await RecurringDb.instance.resetForTesting();
  });

  RecurringRule rule({
    required RecurrenceFrequency freq,
    int interval = 1,
    DateTime? start,
    DateTime? end,
    DateTime? lastRun,
    String type = 'expense',
  }) =>
      RecurringRule(
        id: 'r1',
        accountId: 'acc',
        categoriesId: 'Ăn uống',
        type: type,
        amount: 100,
        frequency: freq,
        interval: interval,
        startDate: start ?? DateTime(2026, 1, 1),
        endDate: end,
        lastRunDate: lastRun,
        createdAt: DateTime(2026, 1, 1),
      );

  test('monthly rule creates one txn per month up to now', () async {
    await RecurringDb.instance.upsert(
      rule(freq: RecurrenceFrequency.monthly, start: DateTime(2026, 1, 15)),
    );
    final fake = _FakeTxRepo();
    final engine = RecurringEngine(txRepo: fake);
    final created = await engine.runDueRules(now: DateTime(2026, 4, 20));
    expect(created, 4); // Jan, Feb, Mar, Apr
    expect(fake.saved.every((t) => t.type == TransactionType.expense), isTrue);
  });

  test('respects endDate', () async {
    await RecurringDb.instance.upsert(rule(
      freq: RecurrenceFrequency.monthly,
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 2, 1),
    ));
    final fake = _FakeTxRepo();
    final created = await RecurringEngine(txRepo: fake)
        .runDueRules(now: DateTime(2026, 12, 31));
    expect(created, 2); // Jan 1, Feb 1
  });

  test('uses lastRunDate as anchor so no duplicates', () async {
    await RecurringDb.instance.upsert(rule(
      freq: RecurrenceFrequency.monthly,
      start: DateTime(2026, 1, 1),
      lastRun: DateTime(2026, 3, 1),
    ));
    final fake = _FakeTxRepo();
    final created = await RecurringEngine(txRepo: fake)
        .runDueRules(now: DateTime(2026, 4, 20));
    expect(created, 1); // only April
  });

  test('income type maps correctly', () async {
    await RecurringDb.instance.upsert(rule(
      freq: RecurrenceFrequency.monthly,
      type: 'income',
      start: DateTime(2026, 4, 1),
    ));
    final fake = _FakeTxRepo();
    await RecurringEngine(txRepo: fake)
        .runDueRules(now: DateTime(2026, 4, 20));
    expect(fake.saved.single.type, TransactionType.income);
  });

  test('no runs when now precedes startDate', () async {
    await RecurringDb.instance.upsert(rule(
      freq: RecurrenceFrequency.daily,
      start: DateTime(2027, 1, 1),
    ));
    final fake = _FakeTxRepo();
    final created = await RecurringEngine(txRepo: fake)
        .runDueRules(now: DateTime(2026, 12, 31));
    expect(created, 0);
  });

  test('weekly interval of 2 runs every other week', () async {
    await RecurringDb.instance.upsert(rule(
      freq: RecurrenceFrequency.weekly,
      interval: 2,
      start: DateTime(2026, 4, 1),
    ));
    final fake = _FakeTxRepo();
    final created = await RecurringEngine(txRepo: fake)
        .runDueRules(now: DateTime(2026, 4, 30));
    expect(created, 3); // Apr 1, Apr 15, Apr 29
  });
}
