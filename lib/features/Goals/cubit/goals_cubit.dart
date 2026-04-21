import 'package:financy_ui/app/services/Local/savings_goals_db.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum GoalsStatus { initial, loading, loaded, error }

class GoalsState {
  final GoalsStatus status;
  final List<SavingsGoal> goals;
  final String? error;

  const GoalsState({
    required this.status,
    required this.goals,
    this.error,
  });

  factory GoalsState.initial() =>
      const GoalsState(status: GoalsStatus.initial, goals: []);

  GoalsState copyWith({
    GoalsStatus? status,
    List<SavingsGoal>? goals,
    String? error,
  }) =>
      GoalsState(
        status: status ?? this.status,
        goals: goals ?? this.goals,
        error: error,
      );
}

class GoalsCubit extends Cubit<GoalsState> {
  GoalsCubit() : super(GoalsState.initial());

  Future<void> load() async {
    emit(state.copyWith(status: GoalsStatus.loading, error: null));
    try {
      final list = await SavingsGoalsDb.instance.all();
      emit(state.copyWith(status: GoalsStatus.loaded, goals: list));
    } catch (e) {
      emit(state.copyWith(status: GoalsStatus.error, error: e.toString()));
    }
  }

  Future<void> save(SavingsGoal g) async {
    await SavingsGoalsDb.instance.upsert(g);
    await load();
  }

  Future<void> remove(String id) async {
    await SavingsGoalsDb.instance.delete(id);
    await load();
  }

  Future<void> deposit(SavingsGoal g, double amount) async {
    if (amount <= 0) return;
    final nextSaved = g.savedAmount + amount;
    final completed =
        nextSaved >= g.targetAmount && g.completedAt == null
            ? DateTime.now()
            : g.completedAt;
    final updated = g.copyWith(
      savedAmount: nextSaved,
      completedAt: completed,
    );
    await save(updated);
  }

  Future<void> withdraw(SavingsGoal g, double amount) async {
    if (amount <= 0) return;
    final nextSaved =
        (g.savedAmount - amount).clamp(0.0, double.infinity).toDouble();
    final updated = g.copyWith(
      savedAmount: nextSaved,
      clearCompleted: nextSaved < g.targetAmount,
    );
    await save(updated);
  }
}
