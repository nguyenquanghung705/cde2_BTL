import 'package:financy_ui/app/services/Local/budget_db.dart';
import 'package:financy_ui/app/services/Local/budget_status.dart';
import 'package:financy_ui/features/Categories/models/categoriesModels.dart';
import 'package:financy_ui/features/transactions/models/transactionsModels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await BudgetDb.instance.resetForTesting();
    await BudgetDb.instance.initForTesting();
  });

  tearDown(() async {
    await BudgetDb.instance.resetForTesting();
  });

  Category cat(String id, String name) => Category(
        id: id,
        name: name,
        type: 'expense',
        icon: 'x',
        color: '0xFF000000',
        createdAt: DateTime(2026, 1, 1),
      );

  Transactionsmodels tx({
    required String categoriesId,
    required double amount,
    required DateTime date,
    TransactionType type = TransactionType.expense,
  }) =>
      Transactionsmodels(
        id: 'i',
        uid: 'u',
        accountId: 'a',
        categoriesId: categoriesId,
        type: type,
        amount: amount,
        transactionDate: date,
      );

  test('status reflects spent vs limit with nearing/over flags', () async {
    final food = cat('c1', 'Ăn uống');
    await BudgetDb.instance
        .upsert(Budget(categoryId: food.id, limit: 1000));
    final txns = {
      DateTime(2026, 4, 1): [
        tx(categoriesId: 'Ăn uống', amount: 850, date: DateTime(2026, 4, 5)),
      ],
    };
    final list = await BudgetStatusCalc.forMonth(
      expenseCategories: [food],
      transactionsByDate: txns,
      year: 2026,
      month: 4,
    );
    expect(list.length, 1);
    expect(list.first.spent, 850);
    expect(list.first.nearing, isTrue);
    expect(list.first.over, isFalse);
  });

  test('over flag when spent exceeds limit', () async {
    final c = cat('c1', 'Ăn uống');
    await BudgetDb.instance.upsert(Budget(categoryId: c.id, limit: 100));
    final txns = {
      DateTime(2026, 4, 1): [
        tx(categoriesId: 'Ăn uống', amount: 150, date: DateTime(2026, 4, 5)),
      ],
    };
    final list = await BudgetStatusCalc.forMonth(
      expenseCategories: [c],
      transactionsByDate: txns,
      year: 2026,
      month: 4,
    );
    expect(list.first.over, isTrue);
    expect(list.first.overBy, 50);
  });

  test('categories without a limit are excluded', () async {
    final c = cat('c1', 'Ăn uống');
    final list = await BudgetStatusCalc.forMonth(
      expenseCategories: [c],
      transactionsByDate: {},
      year: 2026,
      month: 4,
    );
    expect(list, isEmpty);
  });

  test('transactions outside target month are ignored', () async {
    final c = cat('c1', 'Ăn uống');
    await BudgetDb.instance.upsert(Budget(categoryId: c.id, limit: 1000));
    final txns = {
      DateTime(2026, 3, 1): [
        tx(categoriesId: 'Ăn uống', amount: 500, date: DateTime(2026, 3, 15)),
      ],
    };
    final list = await BudgetStatusCalc.forMonth(
      expenseCategories: [c],
      transactionsByDate: txns,
      year: 2026,
      month: 4,
    );
    expect(list.first.spent, 0);
  });

  test('income transactions are not counted', () async {
    final c = cat('c1', 'Ăn uống');
    await BudgetDb.instance.upsert(Budget(categoryId: c.id, limit: 1000));
    final txns = {
      DateTime(2026, 4, 1): [
        tx(
          categoriesId: 'Ăn uống',
          amount: 999,
          date: DateTime(2026, 4, 5),
          type: TransactionType.income,
        ),
      ],
    };
    final list = await BudgetStatusCalc.forMonth(
      expenseCategories: [c],
      transactionsByDate: txns,
      year: 2026,
      month: 4,
    );
    expect(list.first.spent, 0);
  });
}
