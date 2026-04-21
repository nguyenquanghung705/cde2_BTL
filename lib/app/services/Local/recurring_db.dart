import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

enum RecurrenceFrequency { daily, weekly, monthly, yearly }

String _freqToStr(RecurrenceFrequency f) => f.name;
RecurrenceFrequency _freqFromStr(String s) =>
    RecurrenceFrequency.values.firstWhere(
      (e) => e.name == s,
      orElse: () => RecurrenceFrequency.monthly,
    );

class RecurringRule {
  final String id;
  final String accountId;
  final String categoriesId; // keeps parity with Transactionsmodels
  final String type; // 'income' | 'expense'
  final double amount;
  final String? note;
  final RecurrenceFrequency frequency;
  final int interval; // every N units
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? lastRunDate;
  final DateTime createdAt;

  RecurringRule({
    required this.id,
    required this.accountId,
    required this.categoriesId,
    required this.type,
    required this.amount,
    required this.frequency,
    required this.interval,
    required this.startDate,
    required this.createdAt,
    this.endDate,
    this.lastRunDate,
    this.note,
  });

  RecurringRule copyWith({
    DateTime? lastRunDate,
    DateTime? endDate,
    double? amount,
    String? note,
    int? interval,
    RecurrenceFrequency? frequency,
    String? accountId,
    String? categoriesId,
    String? type,
    DateTime? startDate,
  }) =>
      RecurringRule(
        id: id,
        accountId: accountId ?? this.accountId,
        categoriesId: categoriesId ?? this.categoriesId,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        note: note ?? this.note,
        frequency: frequency ?? this.frequency,
        interval: interval ?? this.interval,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        lastRunDate: lastRunDate ?? this.lastRunDate,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'accountId': accountId,
        'categoriesId': categoriesId,
        'type': type,
        'amount': amount,
        'note': note,
        'frequency': _freqToStr(frequency),
        'interval_units': interval,
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate?.millisecondsSinceEpoch,
        'lastRunDate': lastRunDate?.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory RecurringRule.fromMap(Map<String, Object?> m) => RecurringRule(
        id: m['id'] as String,
        accountId: m['accountId'] as String,
        categoriesId: m['categoriesId'] as String,
        type: m['type'] as String,
        amount: (m['amount'] as num).toDouble(),
        note: m['note'] as String?,
        frequency: _freqFromStr(m['frequency'] as String),
        interval: (m['interval_units'] as int?) ?? 1,
        startDate:
            DateTime.fromMillisecondsSinceEpoch(m['startDate'] as int),
        endDate: m['endDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['endDate'] as int)
            : null,
        lastRunDate: m['lastRunDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['lastRunDate'] as int)
            : null,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      );
}

class RecurringDb {
  RecurringDb._();
  static final RecurringDb instance = RecurringDb._();

  static const _table = 'recurring_rules';
  static const _hiveBoxName = 'recurringRulesBox';

  Database? _db;
  Box? _box;
  bool _initialized = false;

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
      final dbPath =
          '${docDir.path}${Platform.pathSeparator}recurring.db';
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute(_schemaSql);
        },
      );
    }
    _initialized = true;
  }

  Future<void> initForTesting() async {
    if (_initialized) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(_schemaSql);
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

  static const _schemaSql = '''
    CREATE TABLE recurring_rules (
      id             TEXT PRIMARY KEY,
      accountId      TEXT NOT NULL,
      categoriesId   TEXT NOT NULL,
      type           TEXT NOT NULL,
      amount         REAL NOT NULL,
      note           TEXT,
      frequency      TEXT NOT NULL,
      interval_units INTEGER NOT NULL DEFAULT 1,
      startDate      INTEGER NOT NULL,
      endDate        INTEGER,
      lastRunDate    INTEGER,
      createdAt      INTEGER NOT NULL
    )
  ''';

  Future<void> upsert(RecurringRule r) async {
    await init();
    if (kIsWeb) {
      await _box!.put(r.id, r.toMap());
    } else {
      await _db!.insert(
        _table,
        r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<RecurringRule>> all() async {
    await init();
    if (kIsWeb) {
      return _box!.values
          .map((e) =>
              RecurringRule.fromMap(Map<String, Object?>.from(e as Map)))
          .toList();
    }
    final rows = await _db!.query(_table, orderBy: 'createdAt DESC');
    return rows.map(RecurringRule.fromMap).toList();
  }

  Future<RecurringRule?> getById(String id) async {
    await init();
    if (kIsWeb) {
      final raw = _box!.get(id);
      if (raw == null) return null;
      return RecurringRule.fromMap(Map<String, Object?>.from(raw as Map));
    }
    final rows =
        await _db!.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return RecurringRule.fromMap(rows.first);
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
