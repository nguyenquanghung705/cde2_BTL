import 'package:financy_ui/app/services/Local/recurring_db.dart';
import 'package:financy_ui/features/Recurring/services/recurring_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum RecurringStatus { initial, loading, loaded, error }

class RecurringState {
  final RecurringStatus status;
  final List<RecurringRule> rules;
  final String? error;
  final int lastRunCreated;

  const RecurringState({
    required this.status,
    required this.rules,
    this.error,
    this.lastRunCreated = 0,
  });

  factory RecurringState.initial() => const RecurringState(
        status: RecurringStatus.initial,
        rules: [],
      );

  RecurringState copyWith({
    RecurringStatus? status,
    List<RecurringRule>? rules,
    String? error,
    int? lastRunCreated,
  }) =>
      RecurringState(
        status: status ?? this.status,
        rules: rules ?? this.rules,
        error: error,
        lastRunCreated: lastRunCreated ?? this.lastRunCreated,
      );
}

class RecurringCubit extends Cubit<RecurringState> {
  RecurringCubit({RecurringEngine? engine})
      : _engine = engine ?? RecurringEngine(),
        super(RecurringState.initial());

  final RecurringEngine _engine;

  Future<void> load() async {
    emit(state.copyWith(status: RecurringStatus.loading, error: null));
    try {
      final rules = await RecurringDb.instance.all();
      emit(state.copyWith(status: RecurringStatus.loaded, rules: rules));
    } catch (e) {
      emit(state.copyWith(status: RecurringStatus.error, error: e.toString()));
    }
  }

  Future<void> save(RecurringRule rule) async {
    await RecurringDb.instance.upsert(rule);
    await load();
  }

  Future<void> remove(String id) async {
    await RecurringDb.instance.delete(id);
    await load();
  }

  /// Runs due rules. Safe to call at app startup and after editing rules.
  Future<int> runNow({DateTime? now}) async {
    try {
      final created = await _engine.runDueRules(now: now);
      emit(state.copyWith(lastRunCreated: created));
      await load();
      return created;
    } catch (e) {
      emit(state.copyWith(status: RecurringStatus.error, error: e.toString()));
      return 0;
    }
  }
}
