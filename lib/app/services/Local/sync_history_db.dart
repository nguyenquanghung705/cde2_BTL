import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A single sync attempt record — succeeded or failed.
class SyncHistoryEntry {
  final int? id;
  final DateTime startedAt;
  final int durationMs;
  final bool success;
  final int itemCount;
  final int attempts;
  final String? errorMessage;

  SyncHistoryEntry({
    this.id,
    required this.startedAt,
    required this.durationMs,
    required this.success,
    required this.itemCount,
    required this.attempts,
    this.errorMessage,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'durationMs': durationMs,
        'success': success ? 1 : 0,
        'itemCount': itemCount,
        'attempts': attempts,
        'errorMessage': errorMessage,
      };

  factory SyncHistoryEntry.fromMap(Map<String, Object?> m) => SyncHistoryEntry(
        id: m['id'] as int?,
        startedAt: DateTime.fromMillisecondsSinceEpoch(m['startedAt'] as int),
        durationMs: m['durationMs'] as int,
        success: (m['success'] as int) == 1,
        itemCount: m['itemCount'] as int,
        attempts: m['attempts'] as int,
        errorMessage: m['errorMessage'] as String?,
      );
}

/// Persistent log of sync attempts. Uses SQLite on native, Hive on web.
///
/// Lives in its own database file (`sync_history.db`) so it doesn't collide
/// with [BudgetDb]'s `financy.db` that is opened separately.
class SyncHistoryDb {
  SyncHistoryDb._();
  static final SyncHistoryDb instance = SyncHistoryDb._();

  static const _table = 'sync_history';
  static const _hiveBoxName = 'syncHistoryBox';
  static const _maxRows = 200;

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
              id            INTEGER PRIMARY KEY AUTOINCREMENT,
              startedAt     INTEGER NOT NULL,
              durationMs    INTEGER NOT NULL,
              success       INTEGER NOT NULL,
              itemCount     INTEGER NOT NULL,
              attempts      INTEGER NOT NULL,
              errorMessage  TEXT
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
      final dbPath =
          '${docDir.path}${Platform.pathSeparator}sync_history.db';
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE $_table (
              id            INTEGER PRIMARY KEY AUTOINCREMENT,
              startedAt     INTEGER NOT NULL,
              durationMs    INTEGER NOT NULL,
              success       INTEGER NOT NULL,
              itemCount     INTEGER NOT NULL,
              attempts      INTEGER NOT NULL,
              errorMessage  TEXT
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_sync_history_startedAt ON $_table(startedAt)',
          );
        },
      );
    }
    _initialized = true;
  }

  Future<void> record(SyncHistoryEntry entry) async {
    await init();
    if (kIsWeb) {
      final key = entry.startedAt.millisecondsSinceEpoch.toString();
      await _box!.put(key, entry.toMap());
      // Trim to last _maxRows
      if (_box!.length > _maxRows) {
        final sortedKeys = _box!.keys.toList()
          ..sort((a, b) => a.toString().compareTo(b.toString()));
        final toDelete = sortedKeys.take(_box!.length - _maxRows).toList();
        await _box!.deleteAll(toDelete);
      }
      return;
    }
    final map = Map<String, Object?>.from(entry.toMap())..remove('id');
    await _db!.insert(_table, map);
    // Trim old rows to keep DB small
    await _db!.execute('''
      DELETE FROM $_table WHERE id NOT IN (
        SELECT id FROM $_table ORDER BY startedAt DESC LIMIT $_maxRows
      )
    ''');
  }

  Future<List<SyncHistoryEntry>> recent({int limit = 50}) async {
    await init();
    if (kIsWeb) {
      final entries = _box!.values
          .map((e) => SyncHistoryEntry.fromMap(
                Map<String, Object?>.from(e as Map),
              ))
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return entries.take(limit).toList();
    }
    final rows = await _db!.query(
      _table,
      orderBy: 'startedAt DESC',
      limit: limit,
    );
    return rows.map(SyncHistoryEntry.fromMap).toList();
  }

  Future<void> clear() async {
    await init();
    if (kIsWeb) {
      await _box!.clear();
    } else {
      await _db!.delete(_table);
    }
  }
}
