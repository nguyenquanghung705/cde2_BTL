import 'package:financy_ui/app/services/Local/budget_db.dart';
import 'package:financy_ui/app/services/Local/notifications.dart';
import 'package:financy_ui/features/Budget/cubit/budget_state.dart';
import 'package:financy_ui/features/Budget/repo/budget_repo.dart';
import 'package:financy_ui/features/Categories/models/categoriesModels.dart';
import 'package:financy_ui/features/transactions/models/transactionsModels.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';

class BudgetCubit extends Cubit<BudgetFeatureState> {
  BudgetCubit() : super(BudgetFeatureState.initial());

  final BudgetRepo _repo = BudgetRepo();
  final Set<String> _warned80 = {};
  final Set<String> _warned100 = {};

  Future<void> load({
    required List<Category> expenseCategories,
    required Map<DateTime, List<Transactionsmodels>> transactionsByDate,
    DateTime? month,
  }) async {
    emit(BudgetFeatureState.loading());
    try {
      final m = month ?? DateTime.now();
      final items = await _repo.statusForMonth(
        expenseCategories: expenseCategories,
        transactionsByDate: transactionsByDate,
        year: m.year,
        month: m.month,
      );
      emit(state.copyWith(status: BudgetStatus.loaded, items: items));
      _maybeNotifyThresholds(items);
    } catch (e) {
      emit(state.copyWith(status: BudgetStatus.error, error: e.toString()));
    }
  }

  Future<void> setLimit({
    required String categoryId,
    required double limit,
    required List<Category> expenseCategories,
    required Map<DateTime, List<Transactionsmodels>> transactionsByDate,
  }) async {
    await _repo.upsert(Budget(categoryId: categoryId, limit: limit));
    _warned80.remove(categoryId);
    _warned100.remove(categoryId);
    await load(
      expenseCategories: expenseCategories,
      transactionsByDate: transactionsByDate,
    );
  }

  Future<void> removeLimit({
    required String categoryId,
    required List<Category> expenseCategories,
    required Map<DateTime, List<Transactionsmodels>> transactionsByDate,
  }) async {
    await _repo.delete(categoryId);
    _warned80.remove(categoryId);
    _warned100.remove(categoryId);
    await load(
      expenseCategories: expenseCategories,
      transactionsByDate: transactionsByDate,
    );
  }

  Future<Budget?> getByCategory(String categoryId) =>
      _repo.getByCategory(categoryId);

  void _maybeNotifyThresholds(List items) {
    if (kIsWeb) return;
    for (final s in items) {
      if (s.limit <= 0) continue;
      final pct = s.spent / s.limit;
      final id = s.category.id;
      if (pct >= 1.0 && !_warned100.contains(id)) {
        _warned100.add(id);
        NotiService().showNotification(
          id: id.hashCode & 0x7fffffff,
          title: 'Vượt ngân sách',
          body:
              '${s.category.name}: đã chi ${s.spent.toStringAsFixed(0)} / ${s.limit.toStringAsFixed(0)}',
        );
      } else if (pct >= 0.8 && pct < 1.0 && !_warned80.contains(id)) {
        _warned80.add(id);
        NotiService().showNotification(
          id: (id.hashCode ^ 0x1) & 0x7fffffff,
          title: 'Sắp chạm hạn mức',
          body:
              '${s.category.name}: ${(pct * 100).toStringAsFixed(0)}% ngân sách tháng',
        );
      }
    }
  }
}
