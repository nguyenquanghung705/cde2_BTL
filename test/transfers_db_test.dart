import 'package:financy_ui/app/services/Local/transfers_db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await TransfersDb.instance.resetForTesting();
    await TransfersDb.instance.initForTesting();
  });

  tearDown(() async {
    await TransfersDb.instance.resetForTesting();
  });

  TransferRecord make(String id, {double amount = 100, DateTime? date}) =>
      TransferRecord(
        id: id,
        fromAccountId: 'A',
        toAccountId: 'B',
        amount: amount,
        transferDate: date ?? DateTime(2026, 4, 20),
        createdAt: DateTime(2026, 4, 20),
      );

  test('insert and listAll returns newest first', () async {
    await TransfersDb.instance
        .insert(make('t1', date: DateTime(2026, 1, 1)));
    await TransfersDb.instance
        .insert(make('t2', date: DateTime(2026, 5, 1)));
    await TransfersDb.instance
        .insert(make('t3', date: DateTime(2026, 3, 1)));
    final list = await TransfersDb.instance.all();
    expect(list.map((e) => e.id).toList(), ['t2', 't3', 't1']);
  });

  test('delete by id removes the record', () async {
    await TransfersDb.instance.insert(make('t1'));
    await TransfersDb.instance.insert(make('t2'));
    await TransfersDb.instance.delete('t1');
    final list = await TransfersDb.instance.all();
    expect(list.length, 1);
    expect(list.single.id, 't2');
  });

  test('insert replaces on conflict with same id', () async {
    await TransfersDb.instance.insert(make('t1', amount: 100));
    await TransfersDb.instance.insert(make('t1', amount: 500));
    final list = await TransfersDb.instance.all();
    expect(list.length, 1);
    expect(list.single.amount, 500);
  });

  test('toMap / fromMap round-trip preserves data', () {
    final t = TransferRecord(
      id: 'x',
      fromAccountId: 'f',
      toAccountId: 't',
      amount: 123.45,
      note: 'rent',
      transferDate: DateTime.fromMillisecondsSinceEpoch(1000),
      createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
    );
    final round = TransferRecord.fromMap(t.toMap());
    expect(round.id, t.id);
    expect(round.amount, t.amount);
    expect(round.note, t.note);
    expect(round.transferDate, t.transferDate);
    expect(round.createdAt, t.createdAt);
  });
}
