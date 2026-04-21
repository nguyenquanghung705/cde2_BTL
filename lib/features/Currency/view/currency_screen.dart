import 'package:financy_ui/app/services/Local/exchange_rates_db.dart';
import 'package:financy_ui/features/Currency/services/exchange_rate_service.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  final _service = ExchangeRateService();
  String _base = 'VND';
  List<ExchangeRate> _rates = [];
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _base = Hive.box('settings').get('default_currency') as String? ?? 'VND';
    _loadCached();
  }

  Future<void> _loadCached() async {
    final list = await ExchangeRatesDb.instance.allForBase(_base);
    if (!mounted) return;
    setState(() => _rates = list);
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await _service.refreshForBase(_base);
      await _loadCached();
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setBase(String base) async {
    setState(() => _base = base);
    await Hive.box('settings').put('default_currency', base);
    await _loadCached();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Tỷ giá & Tiền tệ'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _busy ? null : _refresh,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Tiền tệ mặc định',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ExchangeRateService.supportedCurrencies
                .map(
                  (c) => ChoiceChip(
                    label: Text(c),
                    selected: _base == c,
                    onSelected: (_) => _setBase(c),
                  ),
                )
                .toList(),
          ),
          const Divider(height: 32),
          Text('1 $_base quy đổi', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Lỗi: $_err',
                  style: const TextStyle(color: Colors.red)),
            ),
          if (_rates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Chưa có tỷ giá. Nhấn nút làm mới để tải.'),
            )
          else
            ..._rates.map(
              (r) => Card(
                child: ListTile(
                  title: Text('${r.base} → ${r.quote}'),
                  subtitle: Text(
                    'Cập nhật: ${r.fetchedAt.toLocal().toString().split('.').first}',
                  ),
                  trailing: Text(
                    r.rate.toStringAsFixed(r.rate > 100 ? 0 : 6),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
