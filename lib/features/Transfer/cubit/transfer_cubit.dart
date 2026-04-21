import 'package:financy_ui/app/services/Local/transfers_db.dart';
import 'package:financy_ui/features/Account/models/money_source.dart';
import 'package:financy_ui/features/Transfer/repo/transfer_repo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum TransferStatus { initial, loading, loaded, success, error }

class TransferState {
  final TransferStatus status;
  final List<TransferRecord> items;
  final String? error;

  const TransferState({
    required this.status,
    required this.items,
    this.error,
  });

  factory TransferState.initial() =>
      const TransferState(status: TransferStatus.initial, items: []);

  TransferState copyWith({
    TransferStatus? status,
    List<TransferRecord>? items,
    String? error,
  }) =>
      TransferState(
        status: status ?? this.status,
        items: items ?? this.items,
        error: error,
      );
}

class TransferCubit extends Cubit<TransferState> {
  TransferCubit() : super(TransferState.initial());
  final TransferRepo _repo = TransferRepo();

  Future<void> load() async {
    emit(state.copyWith(status: TransferStatus.loading, error: null));
    try {
      final items = await _repo.listAll();
      emit(state.copyWith(status: TransferStatus.loaded, items: items));
    } catch (e) {
      emit(state.copyWith(status: TransferStatus.error, error: e.toString()));
    }
  }

  Future<bool> submit({
    required MoneySource from,
    required MoneySource to,
    required double amount,
    String? note,
    DateTime? transferDate,
  }) async {
    try {
      await _repo.createTransfer(
        from: from,
        to: to,
        amount: amount,
        note: note,
        transferDate: transferDate,
      );
      await load();
      return true;
    } catch (e) {
      emit(state.copyWith(status: TransferStatus.error, error: e.toString()));
      return false;
    }
  }

  Future<void> delete(TransferRecord t) async {
    try {
      await _repo.rollbackAndDelete(t);
      await load();
    } catch (e) {
      emit(state.copyWith(status: TransferStatus.error, error: e.toString()));
    }
  }
}
