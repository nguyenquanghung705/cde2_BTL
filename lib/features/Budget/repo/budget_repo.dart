import 'package:financy_ui/app/services/Local/budget_db.dart';
import 'package:financy_ui/app/services/Local/budget_status.dart';
import 'package:financy_ui/features/Categories/models/categoriesModels.dart';
import 'package:financy_ui/features/transactions/models/transactionsModels.dart';

class BudgetRepo {
  Future<List<Budget>> getAll() => BudgetDb.instance.all();

  Future<Budget?> getByCategory(String categoryId) =>
      BudgetDb.instance.getByCategory(categoryId);

  Future<void> upsert(Budget budget) => BudgetDb.instance.upsert(budget);

  Future<void> delete(String categoryId) => BudgetDb.instance.delete(categoryId);

  Future<List<CategoryBudgetStatus>> statusForMonth({
    required List<Category> expenseCategories,
    required Map<DateTime, List<Transactionsmodels>> transactionsByDate,
    required int year,
    required int month,
  }) {
    return BudgetStatusCalc.forMonth(
      expenseCategories: expenseCategories,
      transactionsByDate: transactionsByDate,
      year: year,
      month: month,
    );
  }
}
