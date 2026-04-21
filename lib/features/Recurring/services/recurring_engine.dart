import 'package:financy_ui/app/services/Local/recurring_db.dart';
import 'package:financy_ui/features/transactions/models/transactionsModels.dart';
import 'package:financy_ui/features/transactions/repo/transactionsRepo.dart';
import 'package:uuid/uuid.dart';

/// Advances all recurring rules: creates transactions for every occurrence
/// whose due date is in the past (inclusive of today).
///
/// Returns the number of transactions created.
class RecurringEngine {
  RecurringEngine({
    TransactionsRepo? txRepo,
    Uuid? uuid,
  })  : _txRepo = txRepo ?? TransactionsRepo(),
        _uuid = uuid ?? const Uuid();

  final TransactionsRepo _txRepo;
  final Uuid _uuid;

  Future<int> runDueRules({DateTime? now}) async {
    final ref = now ?? DateTime.now();
    final rules = await RecurringDb.instance.all();
    var created = 0;
    for (final rule in rules) {
      created += await _processRule(rule, ref);
    }
    return created;
  }

  Future<int> _processRule(RecurringRule rule, DateTime now) async {
    var created = 0;
    var cursor = rule.lastRunDate == null
        ? rule.startDate
        : _advance(rule.lastRunDate!, rule.frequency, rule.interval);
    var updated = rule;

    while (!cursor.isAfter(now)) {
      if (rule.endDate != null && cursor.isAfter(rule.endDate!)) break;
      final t = Transactionsmodels(
        id: _uuid.v4(),
        uid: '',
        accountId: rule.accountId,
        categoriesId: rule.categoriesId,
        type: rule.type == 'income'
            ? TransactionType.income
            : TransactionType.expense,
        amount: rule.amount,
        note: rule.note,
        transactionDate: cursor,
        createdAt: DateTime.now(),
      );
      await _txRepo.saveToLocal(t);
      created++;
      updated = updated.copyWith(lastRunDate: cursor);
      cursor = _advance(cursor, rule.frequency, rule.interval);
    }

    if (updated.lastRunDate != rule.lastRunDate) {
      await RecurringDb.instance.upsert(updated);
    }
    return created;
  }

  static DateTime _advance(
    DateTime from,
    RecurrenceFrequency freq,
    int interval,
  ) {
    final step = interval < 1 ? 1 : interval;
    switch (freq) {
      case RecurrenceFrequency.daily:
        return DateTime(from.year, from.month, from.day + step);
      case RecurrenceFrequency.weekly:
        return DateTime(from.year, from.month, from.day + 7 * step);
      case RecurrenceFrequency.monthly:
        return DateTime(from.year, from.month + step, from.day);
      case RecurrenceFrequency.yearly:
        return DateTime(from.year + step, from.month, from.day);
    }
  }
}
