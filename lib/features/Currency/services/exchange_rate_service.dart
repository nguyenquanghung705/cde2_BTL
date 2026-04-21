import 'package:dio/dio.dart';
import 'package:financy_ui/app/services/Local/exchange_rates_db.dart';

/// Fetches and caches exchange rates from exchangerate.host (no API key).
///
/// Cache strategy: if a stored rate for (base, quote) is newer than
/// [maxAge], reuse it; otherwise hit the network and upsert.
class ExchangeRateService {
  ExchangeRateService({Dio? dio, ExchangeRatesDb? db})
      : _dio = dio ?? Dio(),
        _db = db ?? ExchangeRatesDb.instance;

  final Dio _dio;
  final ExchangeRatesDb _db;

  static const supportedCurrencies = ['VND', 'USD', 'EUR', 'JPY', 'GBP'];
  static const Duration maxAge = Duration(hours: 24);
  static const _endpoint = 'https://api.exchangerate.host/latest';

  /// Fetches rates for [base] against every currency in [supportedCurrencies],
  /// caching each result. Returns the list of rates now in the cache.
  Future<List<ExchangeRate>> refreshForBase(String base) async {
    final quotes = supportedCurrencies.where((q) => q != base).toList();
    final res = await _dio.get(
      _endpoint,
      queryParameters: {'base': base, 'symbols': quotes.join(',')},
    );
    final rates = (res.data['rates'] as Map?) ?? {};
    final now = DateTime.now();
    final parsed = <ExchangeRate>[];
    for (final entry in rates.entries) {
      final rate = (entry.value as num?)?.toDouble();
      if (rate == null) continue;
      parsed.add(ExchangeRate(
        base: base,
        quote: entry.key.toString(),
        rate: rate,
        fetchedAt: now,
      ));
    }
    await _db.upsertAll(parsed);
    return parsed;
  }

  /// Returns the rate, preferring cache when fresh. Returns null if no network
  /// and no cached value is available.
  Future<double?> rateFor(String base, String quote) async {
    if (base == quote) return 1.0;
    final cached = await _db.get(base, quote);
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <= maxAge) {
      return cached.rate;
    }
    try {
      await refreshForBase(base);
    } catch (_) {
      return cached?.rate; // fall back to stale cache if offline
    }
    return (await _db.get(base, quote))?.rate;
  }

  Future<double?> convert({
    required double amount,
    required String from,
    required String to,
  }) async {
    final r = await rateFor(from, to);
    if (r == null) return null;
    return amount * r;
  }
}
