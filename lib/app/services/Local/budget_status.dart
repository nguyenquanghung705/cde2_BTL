import 'package:financy_ui/app/services/Local/budget_db.dart';
import 'package:financy_ui/features/Categories/models/categoriesModels.dart';
import 'package:financy_ui/features/transactions/models/transactionsModels.dart';

/// Snapshot of a category's spending against its configured monthly limit.
class CategoryBudgetStatus {
  final Category category;
  final double limit;
  final double spent;

  CategoryBudgetStatus({
    required this.category,
    required this.limit,
    required this.spent,
  });

  double get remaining => limit - spent;
  bool get over => spent > limit;
  bool get nearing => !over && limit > 0 && spent / limit >= 0.8;
  double get overBy => over ? spent - limit : 0;
}

class BudgetStatusCalc {
  /// Build a per-category status for the given month.
  ///
  /// [transactionsByDate] comes straight from `TransactionCubit.state`. Only
  /// expense categories with a non-zero limit are returned.
  static Future<List<CategoryBudgetStatus>> forMonth({
    required List<Category> expenseCategories,
    required Map<DateTime, List<Transactionsmodels>> transactionsByDate,
    required int year,
    required int month,
  }) async {
    final result = <CategoryBudgetStatus>[];
    for (final cat in expenseCategories) {
      final budget = await BudgetDb.instance.getByCategory(cat.id);
      if (budget == null || budget.limit <= 0) continue;

      double spent = 0;
      transactionsByDate.forEach((_, list) {
        for (final t in list) {
          if (t.type == TransactionType.expense &&
              t.categoriesId == cat.name &&
              t.transactionDate != null &&
              t.transactionDate!.month == month &&
              t.transactionDate!.year == year) {
            spent += t.amount;
          }
        }
      });
      result.add(CategoryBudgetStatus(
        category: cat,
        limit: budget.limit,
        spent: spent,
      ));
    }
    return result;
  }
}
