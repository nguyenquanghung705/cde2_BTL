import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ExchangeRate {
  final String base;
  final String quote;
  final double rate;
  final DateTime fetchedAt;

  ExchangeRate({
    required this.base,
    required this.quote,
    required this.rate,
    required this.fetchedAt,
  });

  Map<String, Object?> toMap() => {
        'base': base,
        'quote': quote,
        'rate': rate,
        'fetchedAt': fetchedAt.millisecondsSinceEpoch,
      };

  factory ExchangeRate.fromMap(Map<String, Object?> m) => ExchangeRate(
        base: m['base'] as String,
        quote: m['quote'] as String,
        rate: (m['rate'] as num).toDouble(),
        fetchedAt:
            DateTime.fromMillisecondsSinceEpoch(m['fetchedAt'] as int),
      );
}

class ExchangeRatesDb {
  ExchangeRatesDb._();
  static final ExchangeRatesDb instance = ExchangeRatesDb._();

  static const _table = 'exchange_rates';
  static const _hiveBoxName = 'exchangeRatesBox';

  Database? _db;
  Box? _box;
  bool _initialized = false;

  static const _schema = '''
    CREATE TABLE exchange_rates (
      base       TEXT NOT NULL,
      quote      TEXT NOT NULL,
      rate       REAL NOT NULL,
      fetchedAt  INTEGER NOT NULL,
      PRIMARY KEY (base, quote)
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
          '${docDir.path}${Platform.pathSeparator}exchange_rates.db';
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

  Future<void> upsert(ExchangeRate r) async {
    await init();
    if (kIsWeb) {
      await _box!.put('${r.base}_${r.quote}', r.toMap());
    } else {
      await _db!.insert(
        _table,
        r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> upsertAll(Iterable<ExchangeRate> rates) async {
    for (final r in rates) {
      await upsert(r);
    }
  }

  Future<ExchangeRate?> get(String base, String quote) async {
    await init();
    if (base == quote) {
      return ExchangeRate(
        base: base,
        quote: quote,
        rate: 1,
        fetchedAt: DateTime.now(),
      );
    }
    if (kIsWeb) {
      final raw = _box!.get('${base}_$quote');
      if (raw == null) return null;
      return ExchangeRate.fromMap(Map<String, Object?>.from(raw as Map));
    }
    final rows = await _db!.query(
      _table,
      where: 'base = ? AND quote = ?',
      whereArgs: [base, quote],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ExchangeRate.fromMap(rows.first);
  }

  Future<List<ExchangeRate>> allForBase(String base) async {
    await init();
    if (kIsWeb) {
      return _box!.values
          .map((e) =>
              ExchangeRate.fromMap(Map<String, Object?>.from(e as Map)))
          .where((r) => r.base == base)
          .toList();
    }
    final rows =
        await _db!.query(_table, where: 'base = ?', whereArgs: [base]);
    return rows.map(ExchangeRate.fromMap).toList();
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
