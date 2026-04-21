import 'package:financy_ui/app/services/Local/savings_goals_db.dart';
import 'package:financy_ui/features/Goals/cubit/goals_cubit.dart';
import 'package:financy_ui/shared/utils/statistics_utils.dart';
import 'package:financy_ui/shared/utils/thousands_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<GoalsCubit>().load(),
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
        title: const Text('Mục tiêu tiết kiệm'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<GoalsCubit, GoalsState>(
        builder: (context, state) {
          if (state.status == GoalsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.goals.isEmpty) {
            return const Center(
              child: Text('Chưa có mục tiêu nào. Nhấn + để thêm.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: state.goals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _GoalTile(goal: state.goals[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openEditor({SavingsGoal? goal}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _GoalEditor(
          initial: goal,
          onSave: (g) async {
            await context.read<GoalsCubit>().save(g);
            if (mounted) Navigator.pop(ctx);
          },
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final SavingsGoal goal;
  const _GoalTile({required this.goal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = goal.progress;
    final color = goal.isComplete ? Colors.green : theme.primaryColor;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _showActions(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    goal.isComplete ? Icons.emoji_events : Icons.savings,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goal.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '${StatisticsUtils.formatAmount(goal.savedAmount)} / ${StatisticsUtils.formatAmount(goal.targetAmount)} VND',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (goal.deadline != null)
                    Text(
                      'Hạn: ${goal.deadline!.toLocal().toString().split(' ').first}',
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    const SizedBox(),
                  if (goal.suggestedMonthly != null && !goal.isComplete)
                    Text(
                      '≈ ${StatisticsUtils.formatAmount(goal.suggestedMonthly!)} VND/tháng',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.green),
              title: const Text('Nạp vào'),
              onTap: () {
                Navigator.pop(ctx);
                _amountDialog(context, deposit: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle, color: Colors.orange),
              title: const Text('Rút ra'),
              onTap: () {
                Navigator.pop(ctx);
                _amountDialog(context, deposit: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Xoá mục tiêu'),
              onTap: () async {
                Navigator.pop(ctx);
                await context.read<GoalsCubit>().remove(goal.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _amountDialog(BuildContext context,
      {required bool deposit}) async {
    final ctrl = TextEditingController();
    final detach = VndThousandsFormatter.attach(ctrl);
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(deposit ? 'Nạp vào ${goal.name}' : 'Rút khỏi ${goal.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: vndInputFormatters,
          decoration: const InputDecoration(
            labelText: 'Số tiền (VND)',
            suffixText: '₫',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                ctx,
                VndThousandsFormatter.parse(ctrl.text.trim()) ?? 0,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    detach();
    ctrl.dispose();
    if (v == null || v <= 0) return;
    final cubit = context.read<GoalsCubit>();
    if (deposit) {
      await cubit.deposit(goal, v);
    } else {
      await cubit.withdraw(goal, v);
    }
  }
}

class _GoalEditor extends StatefulWidget {
  final SavingsGoal? initial;
  final ValueChanged<SavingsGoal> onSave;

  const _GoalEditor({required this.onSave, this.initial});

  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  DateTime? _deadline;
  VoidCallback? _detachTarget;

  @override
  void initState() {
    super.initState();
    final g = widget.initial;
    if (g != null) {
      _nameCtrl.text = g.name;
      _targetCtrl.text =
          VndThousandsFormatter.format(g.targetAmount.toStringAsFixed(0));
      _deadline = g.deadline;
    }
    _detachTarget = VndThousandsFormatter.attach(_targetCtrl);
  }

  @override
  void dispose() {
    _detachTarget?.call();
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? 'Mục tiêu mới' : 'Sửa mục tiêu',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên mục tiêu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetCtrl,
              keyboardType: TextInputType.number,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: vndInputFormatters,
              decoration: const InputDecoration(
                labelText: 'Số tiền cần đạt (VND)',
                suffixText: '₫',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _deadline == null
                    ? 'Không có hạn'
                    : 'Hạn: ${_deadline!.toLocal().toString().split(' ').first}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_deadline != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _deadline = null),
                    ),
                  const Icon(Icons.edit_calendar),
                ],
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _save, child: const Text('Lưu')),
          ],
        ),
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final target = VndThousandsFormatter.parse(_targetCtrl.text.trim()) ?? 0;
    if (name.isEmpty || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập đủ tên và số tiền')),
      );
      return;
    }
    final existing = widget.initial;
    final goal = SavingsGoal(
      id: existing?.id ?? const Uuid().v4(),
      name: name,
      targetAmount: target,
      savedAmount: existing?.savedAmount ?? 0,
      deadline: _deadline,
      accountId: existing?.accountId,
      createdAt: existing?.createdAt ?? DateTime.now(),
      completedAt: existing?.completedAt,
    );
    widget.onSave(goal);
  }
}
