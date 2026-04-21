import 'package:financy_ui/app/services/Local/recurring_db.dart';
import 'package:financy_ui/features/Account/cubit/manageMoneyCubit.dart';
import 'package:financy_ui/features/Account/models/money_source.dart';
import 'package:financy_ui/features/Categories/cubit/CategoriesCubit.dart';
import 'package:financy_ui/features/Categories/models/categoriesModels.dart';
import 'package:financy_ui/features/Recurring/cubit/recurring_cubit.dart';
import 'package:financy_ui/shared/utils/statistics_utils.dart';
import 'package:financy_ui/shared/utils/thousands_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ManageMoneyCubit>().getAllAccount();
      context.read<Categoriescubit>().loadCategories();
      context.read<RecurringCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Giao dịch định kỳ'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Chạy kiểm tra',
            icon: const Icon(Icons.play_arrow),
            onPressed: () async {
              final n = await context.read<RecurringCubit>().runNow();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã tạo $n giao dịch đến hạn')),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<RecurringCubit, RecurringState>(
        builder: (context, state) {
          if (state.status == RecurringStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.rules.isEmpty) {
            return const Center(child: Text('Chưa có quy tắc định kỳ'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: state.rules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = state.rules[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: r.type == 'income'
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    child: Icon(
                      r.type == 'income'
                          ? Icons.trending_up
                          : Icons.trending_down,
                      color: r.type == 'income' ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(
                    '${r.categoriesId} • ${StatisticsUtils.formatAmount(r.amount)} VND',
                  ),
                  subtitle: Text(
                    'Lặp ${_freqLabel(r.frequency, r.interval)} — bắt đầu '
                    '${r.startDate.toLocal().toString().split(' ').first}'
                    '${r.lastRunDate != null ? '\nLần cuối: ${r.lastRunDate!.toLocal().toString().split(' ').first}' : ''}',
                  ),
                  isThreeLine: r.lastRunDate != null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'delete') {
                        await context.read<RecurringCubit>().remove(r.id);
                      } else if (v == 'edit') {
                        await _openEditor(rule: r);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Sửa')),
                      PopupMenuItem(value: 'delete', child: Text('Xoá')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _freqLabel(RecurrenceFrequency f, int interval) {
    final i = interval < 1 ? 1 : interval;
    switch (f) {
      case RecurrenceFrequency.daily:
        return i == 1 ? 'hằng ngày' : 'mỗi $i ngày';
      case RecurrenceFrequency.weekly:
        return i == 1 ? 'hằng tuần' : 'mỗi $i tuần';
      case RecurrenceFrequency.monthly:
        return i == 1 ? 'hằng tháng' : 'mỗi $i tháng';
      case RecurrenceFrequency.yearly:
        return i == 1 ? 'hằng năm' : 'mỗi $i năm';
    }
  }

  Future<void> _openEditor({RecurringRule? rule}) async {
    final accounts = (context.read<ManageMoneyCubit>().state.listAccounts ??
            <MoneySource>[])
        .toList();
    final cats = context.read<Categoriescubit>().state;
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có ví. Tạo ví trước.')),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _RuleEditor(
          initial: rule,
          accounts: accounts,
          expenseCats: cats.categoriesExpense,
          incomeCats: cats.categoriesIncome,
          onSave: (r) async {
            await context.read<RecurringCubit>().save(r);
            if (mounted) Navigator.pop(ctx);
          },
        ),
      ),
    );
  }
}

class _RuleEditor extends StatefulWidget {
  final RecurringRule? initial;
  final List<MoneySource> accounts;
  final List<Category> expenseCats;
  final List<Category> incomeCats;
  final ValueChanged<RecurringRule> onSave;

  const _RuleEditor({
    required this.accounts,
    required this.expenseCats,
    required this.incomeCats,
    required this.onSave,
    this.initial,
  });

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  // Keep these as primitives — Category and MoneySource are HiveObjects
  // whose equality is identity-based, which breaks DropdownButtonFormField's
  // "value must match exactly one item" invariant when the lists are
  // rebuilt (e.g. on Chi ↔ Thu toggle).
  late String _type;
  String? _accountId;
  String? _categoryName;

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  VoidCallback? _detachAmount;
  late RecurrenceFrequency _freq;
  int _interval = 1;
  late DateTime _startDate;
  DateTime? _endDate;

  List<Category> _catsForType(String type) =>
      type == 'income' ? widget.incomeCats : widget.expenseCats;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _type = r?.type ?? 'expense';
    _freq = r?.frequency ?? RecurrenceFrequency.monthly;
    _interval = r?.interval ?? 1;
    _startDate = r?.startDate ?? DateTime.now();
    _endDate = r?.endDate;
    if (r != null) {
      _amountCtrl.text =
          VndThousandsFormatter.format(r.amount.toStringAsFixed(0));
      _noteCtrl.text = r.note ?? '';
      _accountId = r.accountId;
    } else {
      _accountId =
          widget.accounts.isNotEmpty ? widget.accounts.first.id : null;
    }
    final pool = _catsForType(_type);
    if (r != null && pool.any((c) => c.name == r.categoriesId)) {
      _categoryName = r.categoriesId;
    } else {
      _categoryName = pool.isNotEmpty ? pool.first.name : null;
    }
    _detachAmount = VndThousandsFormatter.attach(_amountCtrl);
  }

  @override
  void dispose() {
    _detachAmount?.call();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = _catsForType(_type);
    // Guard: make sure _categoryName is still valid for the current type —
    // prevents "DropdownButton value not in items" crash when toggling Thu/Chi.
    if (_categoryName == null ||
        !cats.any((c) => c.name == _categoryName)) {
      _categoryName = cats.isNotEmpty ? cats.first.name : null;
    }
    if (_accountId == null ||
        !widget.accounts.any((a) => a.id == _accountId)) {
      _accountId =
          widget.accounts.isNotEmpty ? widget.accounts.first.id : null;
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? 'Thêm quy tắc' : 'Sửa quy tắc',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Chi')),
                ButtonSegment(value: 'income', label: Text('Thu')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                final pool = _catsForType(_type);
                _categoryName = pool.isNotEmpty ? pool.first.name : null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(
                labelText: 'Ví',
                border: OutlineInputBorder(),
              ),
              items: widget.accounts
                  .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // Re-key on _type so the Dropdown rebuilds cleanly when the user
              // toggles Chi ↔ Thu and the items list changes shape.
              key: ValueKey('cat-dropdown-$_type'),
              initialValue: _categoryName,
              decoration: const InputDecoration(
                labelText: 'Danh mục',
                border: OutlineInputBorder(),
              ),
              items: cats
                  .map((c) => DropdownMenuItem(
                        value: c.name,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _categoryName = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: vndInputFormatters,
              decoration: const InputDecoration(
                labelText: 'Số tiền (VND)',
                suffixText: '₫',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<RecurrenceFrequency>(
                    initialValue: _freq,
                    decoration: const InputDecoration(
                      labelText: 'Tần suất',
                      border: OutlineInputBorder(),
                    ),
                    items: RecurrenceFrequency.values
                        .map((f) => DropdownMenuItem(
                              value: f,
                              child: Text(_freqName(f)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _freq = v ?? _freq),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: _interval.toString(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Bước',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _interval = int.tryParse(v) ?? 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Bắt đầu: ${_startDate.toLocal().toString().split(' ').first}',
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _endDate == null
                    ? 'Không giới hạn kết thúc'
                    : 'Kết thúc: ${_endDate!.toLocal().toString().split(' ').first}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_endDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _endDate = null),
                    ),
                  const Icon(Icons.edit_calendar),
                ],
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? _startDate,
                  firstDate: _startDate,
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _endDate = picked);
              },
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _save, child: const Text('Lưu')),
          ],
        ),
      ),
    );
  }

  String _freqName(RecurrenceFrequency f) {
    switch (f) {
      case RecurrenceFrequency.daily:
        return 'Ngày';
      case RecurrenceFrequency.weekly:
        return 'Tuần';
      case RecurrenceFrequency.monthly:
        return 'Tháng';
      case RecurrenceFrequency.yearly:
        return 'Năm';
    }
  }

  void _save() {
    final amt = VndThousandsFormatter.parse(_amountCtrl.text.trim()) ?? 0;
    if (_accountId == null || _categoryName == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập đủ thông tin hợp lệ')),
      );
      return;
    }
    final now = DateTime.now();
    final note =
        _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final rule = RecurringRule(
      id: widget.initial?.id ?? const Uuid().v4(),
      accountId: _accountId!,
      categoriesId: _categoryName!,
      type: _type,
      amount: amt,
      note: note,
      frequency: _freq,
      interval: _interval,
      startDate: _startDate,
      endDate: _endDate,
      lastRunDate: widget.initial?.lastRunDate,
      createdAt: widget.initial?.createdAt ?? now,
    );
    widget.onSave(rule);
  }
}
