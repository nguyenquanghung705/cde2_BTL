import 'dart:io' show Platform;

import 'package:financy_ui/app/services/Local/export_history_db.dart';
import 'package:financy_ui/features/Export/services/csv_exporter.dart';
import 'package:financy_ui/features/transactions/Cubit/transactionCubit.dart';
import 'package:financy_ui/features/transactions/Cubit/transctionState.dart';
import 'package:financy_ui/features/transactions/models/transactionsModels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  List<ExportHistoryEntry> _history = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<TransactionCubit>().fetchTransactionsByDate();
      await _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    final list = await ExportHistoryDb.instance.recent();
    if (!mounted) return;
    setState(() => _history = list);
  }

  Future<void> _pick(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
    }
  }

  Future<void> _export() async {
    if (_to.isBefore(_from)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ngày kết thúc phải sau ngày bắt đầu')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final state = context.read<TransactionCubit>().state;
      final all = <Transactionsmodels>[];
      for (final list in state.transactionsList.values) {
        all.addAll(list);
      }
      final result = await CsvExporter().export(
        transactions: all,
        from: DateTime(_from.year, _from.month, _from.day),
        to: DateTime(_to.year, _to.month, _to.day, 23, 59, 59),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xuất ${result.rowCount} dòng → ${result.filePath}'),
          action: SnackBarAction(
            label: 'Copy đường dẫn',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result.filePath));
            },
          ),
          duration: const Duration(seconds: 8),
        ),
      );
      await _loadHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xuất: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Xuất CSV'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<TransactionCubit, TransactionState>(
        builder: (context, txState) {
          final totalRows = txState.transactionsList.values
              .fold<int>(0, (s, list) => s + list.length);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tổng số giao dịch trong máy: $totalRows'),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Từ: ${_from.toLocal().toString().split(' ').first}',
                  ),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () => _pick(true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Đến: ${_to.toLocal().toString().split(' ').first}',
                  ),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () => _pick(false),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: _busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: const Text('Xuất CSV'),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Text('Lịch sử xuất', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Chưa có lần xuất nào'),
                  )
                else
                  ..._history.map((h) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.description,
                              color: Colors.blueGrey),
                          title: Text(h.filePath.split(Platform.pathSeparator)
                              .last),
                          subtitle: Text(
                            '${h.rowCount} dòng • ${h.exportedAt.toLocal().toString().split('.').first}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            tooltip: 'Copy đường dẫn',
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: h.filePath));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Đã copy đường dẫn')),
                              );
                            },
                          ),
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

