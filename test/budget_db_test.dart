import 'package:financy_ui/app/services/Local/budget_db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await BudgetDb.instance.resetForTesting();
    await BudgetDb.instance.initForTesting();
  });

  tearDown(() async {
    await BudgetDb.instance.resetForTesting();
  });

  test('upsert + getByCategory round-trips', () async {
    final b = Budget(categoryId: 'food', limit: 1000000);
    await BudgetDb.instance.upsert(b);
    final got = await BudgetDb.instance.getByCategory('food');
    expect(got, isNotNull);
    expect(got!.limit, 1000000);
    expect(got.period, 'monthly');
  });

  test('upsert replaces existing row', () async {
    await BudgetDb.instance.upsert(Budget(categoryId: 'food', limit: 100));
    await BudgetDb.instance.upsert(Budget(categoryId: 'food', limit: 500));
    final got = await BudgetDb.instance.getByCategory('food');
    expect(got!.limit, 500);
  });

  test('all returns every budget', () async {
    await BudgetDb.instance.upsert(Budget(categoryId: 'a', limit: 1));
    await BudgetDb.instance.upsert(Budget(categoryId: 'b', limit: 2));
    final list = await BudgetDb.instance.all();
    expect(list.length, 2);
    expect(list.map((e) => e.categoryId).toSet(), {'a', 'b'});
  });

  test('delete removes a budget', () async {
    await BudgetDb.instance.upsert(Budget(categoryId: 'x', limit: 10));
    await BudgetDb.instance.delete('x');
    expect(await BudgetDb.instance.getByCategory('x'), isNull);
  });

  test('getByCategory returns null when missing', () async {
    expect(await BudgetDb.instance.getByCategory('ghost'), isNull);
  });
}
