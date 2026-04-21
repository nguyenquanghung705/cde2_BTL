import 'package:financy_ui/app/services/Local/budget_status.dart';

enum BudgetStatus { initial, loading, loaded, error }

class BudgetFeatureState {
  final BudgetStatus status;
  final List<CategoryBudgetStatus> items;
  final String? error;

  const BudgetFeatureState({
    required this.status,
    required this.items,
    this.error,
  });

  factory BudgetFeatureState.initial() =>
      const BudgetFeatureState(status: BudgetStatus.initial, items: []);

  factory BudgetFeatureState.loading() =>
      const BudgetFeatureState(status: BudgetStatus.loading, items: []);

  BudgetFeatureState copyWith({
    BudgetStatus? status,
    List<CategoryBudgetStatus>? items,
    String? error,
  }) =>
      BudgetFeatureState(
        status: status ?? this.status,
        items: items ?? this.items,
        error: error,
      );
}
