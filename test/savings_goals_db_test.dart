import 'package:financy_ui/app/services/Local/savings_goals_db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await SavingsGoalsDb.instance.resetForTesting();
    await SavingsGoalsDb.instance.initForTesting();
  });

  tearDown(() async {
    await SavingsGoalsDb.instance.resetForTesting();
  });

  SavingsGoal make({
    String id = 'g1',
    double target = 1000,
    double saved = 0,
    DateTime? deadline,
    DateTime? createdAt,
  }) =>
      SavingsGoal(
        id: id,
        name: 'Laptop',
        targetAmount: target,
        savedAmount: saved,
        deadline: deadline,
        createdAt: createdAt ?? DateTime(2026, 1, 1),
      );

  test('upsert + getById round-trips', () async {
    await SavingsGoalsDb.instance
        .upsert(make(saved: 250, deadline: DateTime(2026, 12, 31)));
    final g = await SavingsGoalsDb.instance.getById('g1');
    expect(g, isNotNull);
    expect(g!.savedAmount, 250);
    expect(g.deadline, DateTime(2026, 12, 31));
    expect(g.progress, 0.25);
  });

  test('progress clamps at 1.0 and isComplete reflects', () {
    final g = make(target: 100, saved: 150);
    expect(g.progress, 1.0);
    expect(g.isComplete, isTrue);
    expect(g.remaining, 0);
  });

  test('suggestedMonthly derives from deadline and remaining', () {
    final now = DateTime.now();
    final sixMonths = DateTime(now.year, now.month + 6, now.day);
    final g = SavingsGoal(
      id: 'x',
      name: 'Phone',
      targetAmount: 600,
      savedAmount: 0,
      deadline: sixMonths,
      createdAt: now,
    );
    expect(g.suggestedMonthly, closeTo(100, 0.001));
  });

  test('all returns goals sorted by createdAt DESC', () async {
    await SavingsGoalsDb.instance.upsert(
      make(id: 'a', createdAt: DateTime(2026, 1, 1)),
    );
    await SavingsGoalsDb.instance.upsert(
      make(id: 'b', createdAt: DateTime(2026, 4, 1)),
    );
    await SavingsGoalsDb.instance.upsert(
      make(id: 'c', createdAt: DateTime(2026, 2, 1)),
    );
    final list = await SavingsGoalsDb.instance.all();
    expect(list.map((e) => e.id).toList(), ['b', 'c', 'a']);
  });

  test('delete removes goal', () async {
    await SavingsGoalsDb.instance.upsert(make());
    await SavingsGoalsDb.instance.delete('g1');
    expect(await SavingsGoalsDb.instance.getById('g1'), isNull);
  });

  test('copyWith clearDeadline actually clears', () {
    final g = make(deadline: DateTime(2026, 12, 1));
    final cleared = g.copyWith(clearDeadline: true);
    expect(cleared.deadline, isNull);
  });
}
