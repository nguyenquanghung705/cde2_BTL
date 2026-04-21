import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SavingsGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime? deadline;
  final String? accountId; // optional — associated wallet
  final DateTime createdAt;
  final DateTime? completedAt;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.createdAt,
    this.deadline,
    this.accountId,
    this.completedAt,
  });

  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0.0, 1.0);
  bool get isComplete => savedAmount >= targetAmount;
  double get remaining =>
      (targetAmount - savedAmount).clamp(0, double.infinity);

  /// Suggested monthly contribution to hit the deadline.
  double? get suggestedMonthly {
    if (deadline == null) return null;
    final now = DateTime.now();
    final months = (deadline!.year - now.year) * 12 +
        (deadline!.month - now.month);
    if (months <= 0) return remaining;
    return remaining / months;
  }

  SavingsGoal copyWith({
    String? name,
    double? targetAmount,
    double? savedAmount,
    DateTime? deadline,
    bool clearDeadline = false,
    String? accountId,
    bool clearAccount = false,
    DateTime? completedAt,
    bool clearCompleted = false,
  }) =>
      SavingsGoal(
        id: id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        savedAmount: savedAmount ?? this.savedAmount,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
        accountId: clearAccount ? null : (accountId ?? this.accountId),
        createdAt: createdAt,
        completedAt:
            clearCompleted ? null : (completedAt ?? this.completedAt),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'deadline': deadline?.millisecondsSinceEpoch,
        'accountId': accountId,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'completedAt': completedAt?.millisecondsSinceEpoch,
      };

  factory SavingsGoal.fromMap(Map<String, Object?> m) => SavingsGoal(
        id: m['id'] as String,
        name: m['name'] as String,
        targetAmount: (m['targetAmount'] as num).toDouble(),
        savedAmount: (m['savedAmount'] as num).toDouble(),
        deadline: m['deadline'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['deadline'] as int)
            : null,
        accountId: m['accountId'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
        completedAt: m['completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['completedAt'] as int)
            : null,
      );
}

class SavingsGoalsDb {
  SavingsGoalsDb._();
  static final SavingsGoalsDb instance = SavingsGoalsDb._();

  static const _table = 'savings_goals';
  static const _hiveBoxName = 'savingsGoalsBox';

  Database? _db;
  Box? _box;
  bool _initialized = false;

  static const _schema = '''
    CREATE TABLE savings_goals (
      id            TEXT PRIMARY KEY,
      name          TEXT NOT NULL,
      targetAmount  REAL NOT NULL,
      savedAmount   REAL NOT NULL DEFAULT 0,
      deadline      INTEGER,
      accountId     TEXT,
      createdAt     INTEGER NOT NULL,
      completedAt   INTEGER
    )
  ''';

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
          '${docDir.path}${Platform.pathSeparator}savings_goals.db';
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, _) async => db.execute(_schema),
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
        onCreate: (db, _) async => db.execute(_schema),
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

  Future<void> upsert(SavingsGoal g) async {
    await init();
    if (kIsWeb) {
      await _box!.put(g.id, g.toMap());
    } else {
      await _db!.insert(
        _table,
        g.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<SavingsGoal>> all() async {
    await init();
    if (kIsWeb) {
      return _box!.values
          .map((e) =>
              SavingsGoal.fromMap(Map<String, Object?>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final rows =
        await _db!.query(_table, orderBy: 'createdAt DESC');
    return rows.map(SavingsGoal.fromMap).toList();
  }

  Future<SavingsGoal?> getById(String id) async {
    await init();
    if (kIsWeb) {
      final raw = _box!.get(id);
      if (raw == null) return null;
      return SavingsGoal.fromMap(Map<String, Object?>.from(raw as Map));
    }
    final rows = await _db!
        .query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return SavingsGoal.fromMap(rows.first);
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
