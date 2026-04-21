import 'package:financy_ui/app/services/Local/budget_status.dart';
import 'package:financy_ui/features/Budget/cubit/budget_cubit.dart';
import 'package:financy_ui/features/Budget/cubit/budget_state.dart';
import 'package:financy_ui/features/Categories/cubit/CategoriesCubit.dart';
import 'package:financy_ui/features/Categories/cubit/CategoriesState.dart';
import 'package:financy_ui/features/Categories/models/categoriesModels.dart';
import 'package:financy_ui/features/transactions/Cubit/transactionCubit.dart';
import 'package:financy_ui/features/transactions/Cubit/transctionState.dart';
import 'package:financy_ui/shared/utils/color_utils.dart';
import 'package:financy_ui/shared/utils/mappingIcon.dart';
import 'package:financy_ui/shared/utils/statistics_utils.dart';
import 'package:financy_ui/shared/utils/thousands_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<Categoriescubit>().loadCategories();
      await context.read<TransactionCubit>().fetchTransactionsByDate();
      _reload();
    });
  }

  void _reload() {
    final cats = context.read<Categoriescubit>().state.categoriesExpense;
    final txns = context.read<TransactionCubit>().state.transactionsList;
    context.read<BudgetCubit>().load(
          expenseCategories: cats,
          transactionsByDate: txns,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Ngân sách tháng'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<Categoriescubit, CategoriesState>(
            listenWhen: (p, c) =>
                p.categoriesExpense.length != c.categoriesExpense.length,
            listener: (_, __) => _reload(),
          ),
          BlocListener<TransactionCubit, TransactionState>(
            listenWhen: (p, c) =>
                p.status != c.status &&
                c.status == TransactionStateStatus.loaded,
            listener: (_, __) => _reload(),
          ),
        ],
        child: BlocBuilder<Categoriescubit, CategoriesState>(
          builder: (context, catState) {
            return BlocBuilder<BudgetCubit, BudgetFeatureState>(
              builder: (context, state) {
                if (state.status == BudgetStatus.loading ||
                    catState.status == CategoriesStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final cats = catState.categoriesExpense;
                if (cats.isEmpty) {
                  return const Center(
                      child: Text('Chưa có danh mục chi tiêu'));
                }
                final statusByCatId = {
                  for (final s in state.items) s.category.id: s,
                };
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: cats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final cat = cats[i];
                    final s = statusByCatId[cat.id];
                    return _BudgetTile(
                      category: cat,
                      status: s,
                      onTap: () => _openEditor(context, cat, s),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    Category cat,
    CategoryBudgetStatus? existing,
  ) async {
    final ctrl = TextEditingController(
      text: existing == null || existing.limit <= 0
          ? ''
          : VndThousandsFormatter.format(existing.limit.toStringAsFixed(0)),
    );
    final detach = VndThousandsFormatter.attach(ctrl);
    final result = await showDialog<_EditorResult>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Hạn mức: ${cat.name}'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: vndInputFormatters,
            decoration: const InputDecoration(
              labelText: 'Số tiền / tháng (VND)',
              hintText: '0 = tắt',
              suffixText: '₫',
            ),
          ),
          actions: [
            if (existing != null && existing.limit > 0)
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, const _EditorResult.remove()),
                child: const Text('Xoá'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                final v = VndThousandsFormatter.parse(ctrl.text.trim()) ?? 0;
                Navigator.pop(ctx, _EditorResult.save(v));
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
    detach();
    ctrl.dispose();
    if (result == null) return;
    final cats = context.read<Categoriescubit>().state.categoriesExpense;
    final txns = context.read<TransactionCubit>().state.transactionsList;
    final cubit = context.read<BudgetCubit>();
    if (result.remove || result.amount <= 0) {
      await cubit.removeLimit(
        categoryId: cat.id,
        expenseCategories: cats,
        transactionsByDate: txns,
      );
    } else {
      await cubit.setLimit(
        categoryId: cat.id,
        limit: result.amount,
        expenseCategories: cats,
        transactionsByDate: txns,
      );
    }
  }
}

class _EditorResult {
  final double amount;
  final bool remove;
  const _EditorResult.save(this.amount) : remove = false;
  const _EditorResult.remove()
      : amount = 0,
        remove = true;
}

class _BudgetTile extends StatelessWidget {
  final Category category;
  final CategoryBudgetStatus? status;
  final VoidCallback onTap;

  const _BudgetTile({
    required this.category,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ColorUtils.parseColor(category.color) ?? theme.primaryColor;
    final hasLimit = status != null && status!.limit > 0;
    final pct = hasLimit ? (status!.spent / status!.limit).clamp(0.0, 1.2) : 0.0;
    final over = hasLimit && status!.over;
    final nearing = hasLimit && status!.nearing;
    final barColor = over
        ? Colors.red
        : nearing
            ? Colors.orange
            : color;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(
                  IconMapping.stringToIcon(category.icon),
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(category.name, style: theme.textTheme.titleMedium),
                        if (hasLimit)
                          Text(
                            '${StatisticsUtils.formatAmount(status!.spent)} / ${StatisticsUtils.formatAmount(status!.limit)} VND',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: over ? Colors.red : null,
                              fontWeight:
                                  over ? FontWeight.bold : FontWeight.normal,
                            ),
                          )
                        else
                          Text(
                            'Chưa đặt',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct > 1 ? 1 : pct,
                        minHeight: 8,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation(barColor),
                      ),
                    ),
                    if (over)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Vượt ${StatisticsUtils.formatAmount(status!.overBy)} VND',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
