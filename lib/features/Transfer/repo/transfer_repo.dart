import 'package:financy_ui/app/services/Local/activity_logger.dart';
import 'package:financy_ui/app/services/Local/transfers_db.dart';
import 'package:financy_ui/features/Account/models/money_source.dart';
import 'package:financy_ui/features/Account/repo/manageMoneyRepo.dart';
import 'package:uuid/uuid.dart';

class TransferRepo {
  final ManageMoneyRepo _accountRepo = ManageMoneyRepo();
  final _uuid = const Uuid();

  Future<TransferRecord> createTransfer({
    required MoneySource from,
    required MoneySource to,
    required double amount,
    String? note,
    DateTime? transferDate,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Số tiền chuyển phải lớn hơn 0');
    }
    if (from.id == to.id) {
      throw ArgumentError('Ví nguồn và đích phải khác nhau');
    }
    if (from.balance < amount) {
      throw StateError('Số dư không đủ ở ví ${from.name}');
    }

    from.balance -= amount;
    to.balance += amount;
    await _accountRepo.updateInLocal(from);
    await _accountRepo.updateInLocal(to);

    final record = TransferRecord(
      id: _uuid.v4(),
      fromAccountId: from.id ?? '',
      toAccountId: to.id ?? '',
      amount: amount,
      note: note,
      transferDate: transferDate ?? DateTime.now(),
      createdAt: DateTime.now(),
    );
    await TransfersDb.instance.insert(record);
    await ActivityLogger.log('transfer_created', data: {
      'from': from.id,
      'to': to.id,
      'amount': amount,
    });
    return record;
  }

  Future<List<TransferRecord>> listAll() => TransfersDb.instance.all();

  Future<void> rollbackAndDelete(TransferRecord t) async {
    final from = _accountRepo.getFromLocalById(t.fromAccountId);
    final to = _accountRepo.getFromLocalById(t.toAccountId);
    if (from != null) {
      from.balance += t.amount;
      await _accountRepo.updateInLocal(from);
    }
    if (to != null) {
      to.balance -= t.amount;
      await _accountRepo.updateInLocal(to);
    }
    await TransfersDb.instance.delete(t.id);
  }
}
