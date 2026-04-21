import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Internal transfer of money between two of the user's wallets.
///
/// Transfers are NOT counted as income or expense — they represent a
/// zero-sum movement. Stored separately from Hive transactions.
class TransferRecord {
  final String id;
  final String fromAccountId;
  final String toAccountId;
  final double amount;
  final String? note;
  final DateTime transferDate;
  final DateTime createdAt;

  TransferRecord({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.transferDate,
    required this.createdAt,
    this.note,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'amount': amount,
        'note': note,
        'transferDate': transferDate.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory TransferRecord.fromMap(Map<String, Object?> m) => TransferRecord(
        id: m['id'] as String,
        fromAccountId: m['fromAccountId'] as String,
        toAccountId: m['toAccountId'] as String,
        amount: (m['amount'] as num).toDouble(),
        note: m['note'] as String?,
        transferDate:
            DateTime.fromMillisecondsSinceEpoch(m['transferDate'] as int),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      );
}

class TransfersDb {
  TransfersDb._();
  static final TransfersDb instance = TransfersDb._();

  static const _table = 'transfers';
  static const _hiveBoxName = 'transfersBox';

  Database? _db;
  Box? _box;
  bool _initialized = false;

  Future<void> initForTesting() async {
    if (_initialized) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE $_table (
              id             TEXT PRIMARY KEY,
              fromAccountId  TEXT NOT NULL,
              toAccountId    TEXT NOT NULL,
              amount         REAL NOT NULL,
              note           TEXT,
              transferDate   INTEGER NOT NULL,
              createdAt      INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    _initialized = true;
  }

  Future<void> resetForTesting() async {
    await _db?.close();
    await _box?.close();
    _db = null;
    _box = null;
    _initialized = false;
  }

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _box = await Hive.openBox(_hiveBoxName);
    } else {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      final docDir = await getApplicationDocumentsDirectory();
      final dbPath = '${docDir.path}${Platform.pathSeparator}transfers.db';
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE $_table (
              id             TEXT PRIMARY KEY,
              fromAccountId  TEXT NOT NULL,
              toAccountId    TEXT NOT NULL,
              amount         REAL NOT NULL,
              note           TEXT,
              transferDate   INTEGER NOT NULL,
              createdAt      INTEGER NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_transfers_date ON $_table(transferDate)',
          );
          await db.execute(
            'CREATE INDEX idx_transfers_from ON $_table(fromAccountId)',
          );
          await db.execute(
            'CREATE INDEX idx_transfers_to ON $_table(toAccountId)',
          );
        },
      );
    }
    _initialized = true;
  }

  Future<void> insert(TransferRecord t) async {
    await init();
    if (kIsWeb) {
      await _box!.put(t.id, t.toMap());
    } else {
      await _db!.insert(
        _table,
        t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<TransferRecord>> all() async {
    await init();
    if (kIsWeb) {
      final list = _box!.values
          .map((e) =>
              TransferRecord.fromMap(Map<String, Object?>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.transferDate.compareTo(a.transferDate));
      return list;
    }
    final rows =
        await _db!.query(_table, orderBy: 'transferDate DESC');
    return rows.map(TransferRecord.fromMap).toList();
  }

  Future<void> delete(String id) async {
    await init();
    if (kIsWeb) {
      await _box!.delete(id);
    } else {
      await _db!.delete(_table, where: 'id = ?', whereArgs: [id]);
    }
  }
}
