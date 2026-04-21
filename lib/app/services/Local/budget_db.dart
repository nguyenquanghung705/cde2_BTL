import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Per-category spending budget.
class Budget {
  final String categoryId;
  final double limit;
  final String period; // 'monthly' (default)
  final DateTime updatedAt;

  Budget({
    required this.categoryId,
    required this.limit,
    this.period = 'monthly',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
        'categoryId': categoryId,
        'limit_amount': limit,
        'period': period,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
        categoryId: m['categoryId'] as String,
        limit: (m['limit_amount'] as num).toDouble(),
        period: m['period'] as String? ?? 'monthly',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );
}

/// Storage for category budgets.
///
/// Uses SQLite on Android/iOS (via `sqflite`) and on Windows/macOS/Linux
/// (via `sqflite_common_ffi`). Web uses a Hive box since `sqflite` has no
/// web implementation — same API, so call sites stay identical.
class BudgetDb {
  BudgetDb._();
  static final BudgetDb instance = BudgetDb._();

  static const _table = 'budgets';
  static const _hiveBoxName = 'budgetBox';

  Database? _db;
  Box? _box;
  bool _initialized = false;

  /// Test-only: initialize with an in-memory SQLite DB (no path_provider).
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
              categoryId   TEXT PRIMARY KEY,
              limit_amount REAL NOT NULL,
              period       TEXT NOT NULL DEFAULT 'monthly',
              updatedAt    INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    _initialized = true;
  }

  /// Test-only: reset singleton so each test starts fresh.
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
      // Desktop needs ffi init; mobile uses the default sqflite plugin.
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      final docDir = await getApplicationDocumentsDirectory();
      final dbPath = '${docDir.path}${Platform.pathSeparator}financy.db';
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE $_table (
              categoryId   TEXT PRIMARY KEY,
              limit_amount REAL NOT NULL,
              period       TEXT NOT NULL DEFAULT 'monthly',
              updatedAt    INTEGER NOT NULL
            )
          ''');
        },
      );
    }
    _initialized = true;
  }

  Future<void> upsert(Budget budget) async {
    await init();
    if (kIsWeb) {
      await _box!.put(budget.categoryId, budget.toMap());
    } else {
      await _db!.insert(
        _table,
        budget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<Budget?> getByCategory(String categoryId) async {
    await init();
    if (kIsWeb) {
      final raw = _box!.get(categoryId);
      if (raw == null) return null;
      return Budget.fromMap(Map<String, Object?>.from(raw as Map));
    }
    final rows = await _db!.query(
      _table,
      where: 'categoryId = ?',
      whereArgs: [categoryId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Budget.fromMap(rows.first);
  }

  Future<List<Budget>> all() async {
    await init();
    if (kIsWeb) {
      return _box!.values
          .map((e) => Budget.fromMap(Map<String, Object?>.from(e as Map)))
          .toList();
    }
    final rows = await _db!.query(_table);
    return rows.map(Budget.fromMap).toList();
  }

  Future<void> delete(String categoryId) async {
    await init();
    if (kIsWeb) {
      await _box!.delete(categoryId);
    } else {
      await _db!.delete(
        _table,
        where: 'categoryId = ?',
        whereArgs: [categoryId],
      );
    }
  }
}
