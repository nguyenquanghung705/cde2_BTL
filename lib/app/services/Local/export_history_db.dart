import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ExportHistoryEntry {
  final int? id;
  final String filePath;
  final DateTime exportedAt;
  final DateTime fromDate;
  final DateTime toDate;
  final int rowCount;

  ExportHistoryEntry({
    this.id,
    required this.filePath,
    required this.exportedAt,
    required this.fromDate,
    required this.toDate,
    required this.rowCount,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'filePath': filePath,
        'exportedAt': exportedAt.millisecondsSinceEpoch,
        'fromDate': fromDate.millisecondsSinceEpoch,
        'toDate': toDate.millisecondsSinceEpoch,
        'rowCount': rowCount,
      };

  factory ExportHistoryEntry.fromMap(Map<String, Object?> m) =>
      ExportHistoryEntry(
        id: m['id'] as int?,
        filePath: m['filePath'] as String,
        exportedAt:
            DateTime.fromMillisecondsSinceEpoch(m['exportedAt'] as int),
        fromDate: DateTime.fromMillisecondsSinceEpoch(m['fromDate'] as int),
        toDate: DateTime.fromMillisecondsSinceEpoch(m['toDate'] as int),
        rowCount: m['rowCount'] as int,
      );
}

class ExportHistoryDb {
  ExportHistoryDb._();
  static final ExportHistoryDb instance = ExportHistoryDb._();

  static const _table = 'exports';
  static const _hiveBoxName = 'exportHistoryBox';

  Database? _db;
  Box? _box;
  bool _initialized = false;

  static const _schema = '''
    CREATE TABLE exports (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      filePath    TEXT NOT NULL,
      exportedAt  INTEGER NOT NULL,
      fromDate    INTEGER NOT NULL,
      toDate      INTEGER NOT NULL,
      rowCount    INTEGER NOT NULL
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
          '${docDir.path}${Platform.pathSeparator}export_history.db';
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

  Future<void> record(ExportHistoryEntry entry) async {
    await init();
    if (kIsWeb) {
      await _box!
          .put(entry.exportedAt.millisecondsSinceEpoch.toString(), entry.toMap());
      return;
    }
    final map = Map<String, Object?>.from(entry.toMap())..remove('id');
    await _db!.insert(_table, map);
  }

  Future<List<ExportHistoryEntry>> recent({int limit = 50}) async {
    await init();
    if (kIsWeb) {
      return _box!.values
          .map((e) =>
              ExportHistoryEntry.fromMap(Map<String, Object?>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.exportedAt.compareTo(a.exportedAt));
    }
    final rows = await _db!
        .query(_table, orderBy: 'exportedAt DESC', limit: limit);
    return rows.map(ExportHistoryEntry.fromMap).toList();
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
