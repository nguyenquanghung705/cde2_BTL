import 'package:financy_ui/features/Account/cubit/manageMoneyCubit.dart';
import 'package:financy_ui/features/Account/cubit/manageMoneyState.dart';
import 'package:financy_ui/features/Account/models/money_source.dart';
import 'package:financy_ui/features/Transfer/cubit/transfer_cubit.dart';
import 'package:financy_ui/shared/utils/statistics_utils.dart';
import 'package:financy_ui/shared/utils/thousands_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  MoneySource? _from;
  MoneySource? _to;
  DateTime _date = DateTime.now();
  VoidCallback? _detachAmount;

  @override
  void initState() {
    super.initState();
    _detachAmount = VndThousandsFormatter.attach(_amountCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ManageMoneyCubit>().getAllAccount();
      context.read<TransferCubit>().load();
    });
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Chuyển khoản giữa ví'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<ManageMoneyCubit, ManageMoneyState>(
        builder: (context, accState) {
          final accounts = accState.listAccounts ?? <MoneySource>[];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _accountPicker(
                  label: 'Từ ví',
                  value: _from,
                  accounts: accounts,
                  onChanged: (v) => setState(() => _from = v),
                ),
                const SizedBox(height: 12),
                _accountPicker(
                  label: 'Đến ví',
                  value: _to,
                  accounts: accounts.where((a) => a.id != _from?.id).toList(),
                  onChanged: (v) => setState(() => _to = v),
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
                    labelText: 'Ghi chú (tuỳ chọn)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    'Ngày: ${_date.toLocal().toString().split(' ').first}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Thực hiện chuyển'),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Text('Lịch sử chuyển khoản',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                BlocBuilder<TransferCubit, TransferState>(
                  builder: (context, state) {
                    if (state.items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Chưa có giao dịch chuyển khoản'),
                      );
                    }
                    return Column(
                      children: state.items.map((t) {
                        final fromName = accounts
                            .where((a) => a.id == t.fromAccountId)
                            .map((a) => a.name)
                            .firstWhere((_) => true,
                                orElse: () => t.fromAccountId);
                        final toName = accounts
                            .where((a) => a.id == t.toAccountId)
                            .map((a) => a.name)
                            .firstWhere((_) => true,
                                orElse: () => t.toAccountId);
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.swap_horiz,
                                color: Colors.blue),
                            title: Text('$fromName → $toName'),
                            subtitle: Text(
                              '${StatisticsUtils.formatAmount(t.amount)} VND • ${t.transferDate.toLocal().toString().split(' ').first}'
                              '${t.note != null && t.note!.isNotEmpty ? '\n${t.note}' : ''}',
                            ),
                            isThreeLine:
                                t.note != null && t.note!.isNotEmpty,
                            trailing: IconButton(
                              icon:
                                  const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(t),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _accountPicker({
    required String label,
    required MoneySource? value,
    required List<MoneySource> accounts,
    required ValueChanged<MoneySource?> onChanged,
  }) {
    return DropdownButtonFormField<MoneySource>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: accounts
          .map((a) => DropdownMenuItem(
                value: a,
                child: Text(
                  '${a.name} (${StatisticsUtils.formatAmount(a.balance)} VND)',
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _submit() async {
    final from = _from;
    final to = _to;
    final amount = VndThousandsFormatter.parse(_amountCtrl.text.trim()) ?? 0;
    if (from == null || to == null) {
      _snack('Chọn đầy đủ ví nguồn và đích');
      return;
    }
    if (amount <= 0) {
      _snack('Nhập số tiền hợp lệ');
      return;
    }
    final ok = await context.read<TransferCubit>().submit(
          from: from,
          to: to,
          amount: amount,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          transferDate: _date,
        );
    if (!mounted) return;
    if (ok) {
      _amountCtrl.clear();
      _noteCtrl.clear();
      await context.read<ManageMoneyCubit>().getAllAccount();
      _snack('Đã chuyển thành công');
    } else {
      final err = context.read<TransferCubit>().state.error;
      _snack(err ?? 'Không thể chuyển');
    }
  }

  Future<void> _confirmDelete(dynamic t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá giao dịch chuyển?'),
        content: const Text('Số dư hai ví sẽ được hoàn trả.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<TransferCubit>().delete(t);
      if (!mounted) return;
      await context.read<ManageMoneyCubit>().getAllAccount();
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
