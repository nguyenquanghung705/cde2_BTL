import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A single user-facing event — screen view, button tap, login attempt, etc.
class ActivityEntry {
  final int? id;
  final DateTime timestamp;
  final String event; // short slug: 'nav', 'login_email', 'export_csv', ...
  final String? route;
  final Map<String, Object?>? data;

  ActivityEntry({
    this.id,
    required this.timestamp,
    required this.event,
    this.route,
    this.data,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'event': event,
        'route': route,
        'data': data == null ? null : jsonEncode(data),
      };

  factory ActivityEntry.fromMap(Map<String, Object?> m) => ActivityEntry(
        id: m['id'] as int?,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
        event: m['event'] as String,
        route: m['route'] as String?,
        data: m['data'] == null
            ? null
            : Map<String, Object?>.from(
                jsonDecode(m['data'] as String) as Map),
      );
}

class ActivityLogDb {
  ActivityLogDb._();
  static final ActivityLogDb instance = ActivityLogDb._();

  static const _table = 'activity_log';
  static const _hiveBoxName = 'activityLogBox';
  static const _maxRows = 1000;

  Database? _db;
  Box? _box;
  bool _initialized = false;

  static const _schema = '''
    CREATE TABLE activity_log (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp  INTEGER NOT NULL,
      event      TEXT NOT NULL,
      route      TEXT,
      data       TEXT
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
          '${docDir.path}${Platform.pathSeparator}activity_log.db';
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute(_schema);
          await db.execute(
            'CREATE INDEX idx_activity_log_ts ON $_table(timestamp)',
          );
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

  Future<void> record(ActivityEntry entry) async {
    await init();
    if (kIsWeb) {
      await _box!.put(
        entry.timestamp.millisecondsSinceEpoch.toString(),
        entry.toMap(),
      );
      if (_box!.length > _maxRows) {
        final keys = _box!.keys.toList()
          ..sort((a, b) => a.toString().compareTo(b.toString()));
        await _box!.deleteAll(keys.take(_box!.length - _maxRows));
      }
      return;
    }
    final map = Map<String, Object?>.from(entry.toMap())..remove('id');
    await _db!.insert(_table, map);
    await _db!.execute('''
      DELETE FROM $_table WHERE id NOT IN (
        SELECT id FROM $_table ORDER BY timestamp DESC LIMIT $_maxRows
      )
    ''');
  }

  Future<List<ActivityEntry>> recent({int limit = 100}) async {
    await init();
    if (kIsWeb) {
      final list = _box!.values
          .map((e) =>
              ActivityEntry.fromMap(Map<String, Object?>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list.take(limit).toList();
    }
    final rows = await _db!.query(
      _table,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(ActivityEntry.fromMap).toList();
  }

  Future<int> count() async {
    await init();
    if (kIsWeb) return _box!.length;
    final r =
        await _db!.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return (r.first['c'] as int?) ?? 0;
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
