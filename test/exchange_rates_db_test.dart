import 'package:dio/dio.dart';
import 'package:dio/src/adapter.dart';
import 'package:financy_ui/app/services/Local/exchange_rates_db.dart';
import 'package:financy_ui/features/Currency/services/exchange_rate_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.payload);
  final Map<String, dynamic> payload;
  int calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      _encode(payload),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  static String _encode(Map<String, dynamic> p) {
    final rates =
        (p['rates'] as Map).entries.map((e) => '"${e.key}":${e.value}').join(',');
    return '{"rates":{$rates}}';
  }
}

void main() {
  setUp(() async {
    await ExchangeRatesDb.instance.resetForTesting();
    await ExchangeRatesDb.instance.initForTesting();
  });

  tearDown(() async {
    await ExchangeRatesDb.instance.resetForTesting();
  });

  test('upsert + get round-trips a rate', () async {
    await ExchangeRatesDb.instance.upsert(ExchangeRate(
      base: 'VND',
      quote: 'USD',
      rate: 0.00004,
      fetchedAt: DateTime(2026, 4, 20),
    ));
    final got = await ExchangeRatesDb.instance.get('VND', 'USD');
    expect(got, isNotNull);
    expect(got!.rate, 0.00004);
  });

  test('same base/quote returns rate 1.0', () async {
    final got = await ExchangeRatesDb.instance.get('USD', 'USD');
    expect(got!.rate, 1.0);
  });

  test('allForBase filters by base', () async {
    await ExchangeRatesDb.instance.upsert(ExchangeRate(
        base: 'VND', quote: 'USD', rate: 0.00004, fetchedAt: DateTime.now()));
    await ExchangeRatesDb.instance.upsert(ExchangeRate(
        base: 'USD', quote: 'VND', rate: 25000, fetchedAt: DateTime.now()));
    final list = await ExchangeRatesDb.instance.allForBase('USD');
    expect(list.length, 1);
    expect(list.single.quote, 'VND');
  });

  test('ExchangeRateService caches and reuses within maxAge', () async {
    final dio = Dio();
    final adapter = _FakeAdapter({
      'rates': {'USD': 0.00004, 'EUR': 0.00003}
    });
    dio.httpClientAdapter = adapter;
    final service = ExchangeRateService(dio: dio);

    final r1 = await service.rateFor('VND', 'USD');
    final r2 = await service.rateFor('VND', 'USD');
    expect(r1, 0.00004);
    expect(r2, 0.00004);
    // Only 1 network call — second served from fresh cache.
    expect(adapter.calls, 1);
  });

  test('convert multiplies amount by rate', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter({
      'rates': {'USD': 0.00004}
    });
    final service = ExchangeRateService(dio: dio);
    final out = await service.convert(
      amount: 1000000,
      from: 'VND',
      to: 'USD',
    );
    expect(out, closeTo(40, 0.0001));
  });
}
