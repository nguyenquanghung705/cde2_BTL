// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously, unrelated_type_equality_checks

import 'dart:developer';

import 'package:financy_ui/app/services/Local/budget_db.dart';
import 'package:financy_ui/features/Account/cubit/manageMoneyCubit.dart';
import 'package:financy_ui/features/Account/models/money_source.dart';
import 'package:financy_ui/features/Categories/cubit/CategoriesCubit.dart';
import 'package:financy_ui/features/transactions/Cubit/transactionCubit.dart';
import 'package:financy_ui/shared/utils/currency.dart';
import 'package:financy_ui/shared/utils/statistics_utils.dart';
import 'package:financy_ui/features/Users/Cubit/userCubit.dart';
import 'package:financy_ui/features/transactions/Cubit/transctionState.dart';
import 'package:financy_ui/features/transactions/models/transactionsModels.dart';
import 'package:financy_ui/shared/utils/generateID.dart';
import 'package:financy_ui/shared/utils/thousands_formatter.dart';
import 'package:financy_ui/shared/widgets/resultDialogAnimation.dart';
import 'package:financy_ui/shared/utils/mappingIcon.dart';
import 'package:financy_ui/core/constants/icons.dart';
import 'package:financy_ui/features/Categories/models/categoriesModels.dart';
import 'package:financy_ui/shared/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:financy_ui/l10n/app_localizations.dart';
import 'package:financy_ui/core/constants/colors.dart';

// Helper class for validation results
class ValidationResult {
  final bool isValid;
  final double? amount;
  final DateTime? date;
  final MoneySource? account;

  ValidationResult({
    required this.isValid,
    this.amount,
    this.date,
    this.account,
  });
}

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  // Placeholder when the transaction's original account no longer exists
  static const String missingAccountPlaceholder = 'Tài khoản đã không tồn tại';
  int selectedTransactionType = 0;
  TextEditingController amountController = TextEditingController();
  TextEditingController noteController = TextEditingController();
  String selectedCategory = 'Select Category';
  String selectedDate = 'Today';
  String selectedAccount = 'Select Account';

  // For editing mode
  Transactionsmodels? editingTransaction;
  MoneySource? oldAccount;
  bool isEditing = false;
  String? fromScreen;

  // Get default categories based on transaction type
  late List<Category> availableCategories;

  // Default colors for each category group
  final Map<String, Color> categoryColors = {
    'Expense': AppColors.red,
    'Income': AppColors.green,
  };

  late List<MoneySource> listAccounts;

  // Helper function for localization
  String _localText(String Function(AppLocalizations) getter) {
    final appLocal = AppLocalizations.of(context);
    return appLocal != null ? getter(appLocal) : '';
  }

  void _populateFieldsForEditing() {
    if (editingTransaction != null) {
      setState(() {
        // Set transaction type
        selectedTransactionType =
            editingTransaction!.type == TransactionType.income ? 0 : 1;

        // Set amount
        amountController.text = VndThousandsFormatter.format(
          editingTransaction!.amount.toInt().toString(),
        );

        // Set category
        selectedCategory = editingTransaction!.categoriesId;

        // Set date
        if (editingTransaction!.transactionDate != null) {
          final date = editingTransaction!.transactionDate!;
          selectedDate = "${date.day}/${date.month}/${date.year}";
        }

        // Set account: if original account no longer exists, show placeholder instead of defaulting
        final matches =
            listAccounts
                .where((acc) => acc.id == editingTransaction!.accountId)
                .toList();
        if (matches.isEmpty) {
          selectedAccount = missingAccountPlaceholder;
          oldAccount = null;
        } else {
          selectedAccount = matches.first.name;
          oldAccount = matches.first;
        }

        // Set note
        noteController.text = editingTransaction!.note ?? '';
      });
    }
  }

  VoidCallback? _detachAmountFormatting;

  @override
  void initState() {
    listAccounts =
        (context.read<ManageMoneyCubit>().listAccounts ?? [])
            .where((e) => e.isActive == true)
            .toList();
    // Luôn khởi tạo với expense (chi tiêu) khi vào màn hình
    selectedTransactionType = 1;
    availableCategories = defaultExpenseCategories;

    // Live VND dot-separator formatting via a controller listener — keeps
    // the engine's InputFormatter pipeline free of rewrites, which was the
    // source of the "typed 111 becomes 11123" bug on Chrome.
    _detachAmountFormatting =
        VndThousandsFormatter.attach(amountController);

    // Check if we're in editing mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        if (args['transaction'] is Transactionsmodels) {
          editingTransaction = args['transaction'];
          final found =
              listAccounts
                  .where((e) => e.id == editingTransaction?.accountId)
                  .toList();
          oldAccount = found.isNotEmpty ? found.first : null;
          isEditing = true;
          _populateFieldsForEditing();
        }
        if (args['fromScreen'] is String) {
          fromScreen = args['fromScreen'];
        }
      } else if (args is Transactionsmodels) {
        editingTransaction = args;
        final found =
            listAccounts
                .where((e) => e.id == editingTransaction?.accountId)
                .toList();
        oldAccount = found.isNotEmpty ? found.first : null;
        isEditing = true;
        _populateFieldsForEditing();
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _detachAmountFormatting?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeAccounts =
        (context.read<ManageMoneyCubit>().state.listAccounts ?? [])
            .where((e) => e.isActive == true)
            .toList();
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading:
            isEditing
                ? IconButton(
                  onPressed: () {
                    if (fromScreen == 'wallet') {
                      Navigator.pop(context);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  icon: Icon(Icons.arrow_back_ios, color: theme.highlightColor),
                )
                : null,
        title: Text(
          isEditing ? 'Edit Transaction' : _localText((l) => l.add),
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: true,
      ),
      body: BlocListener<TransactionCubit, TransactionState>(
        listener: (listenerContext, state) async {
          if (state.status == TransactionStateStatus.success) {
            // TransactionCubit đã tự fetch lại từ Hive và emit loaded rồi
            // Chỉ cần sync account name và show result
            final accountID =
                context
                    .read<ManageMoneyCubit>()
                    .getAccountByName(selectedAccount)
                    ?.id ??
                '';
            context.read<ManageMoneyCubit>().setCurrentAccountName(accountID);
            _showResultEvent(listenerContext, true, context);
            amountController.clear();
            noteController.clear();
          }
          if (state.status == TransactionStateStatus.error) {
            _showResultEvent(listenerContext, false, context);
          }
        },
        child: Column(
          children: [
            // Transaction Type Tabs
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  _buildTabButton(_localText((l) => l.income), 0),
                  SizedBox(width: 8),
                  _buildTabButton(_localText((l) => l.expense), 1),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount Field
                      _buildInputField(
                        label: _localText((l) => l.transactionAmount),
                        child: TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: false,
                            signed: false,
                          ),
                          // Suppress Chrome spellcheck / autocomplete which can
                          // re-fire input events on a formatted numeric field.
                          autocorrect: false,
                          enableSuggestions: false,
                          // Only allow digits at the engine level — dots are
                          // re-inserted *after* commit by the controller
                          // listener installed in initState.
                          inputFormatters: vndInputFormatters,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            suffixText: '₫',
                            border: InputBorder.none,
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textGrey,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Category Field
                      _buildSelectField(
                        label: _localText((l) => l.category),
                        value: selectedCategory,
                        onTap: () => _showCategoryBottomSheet(),
                      ),

                      SizedBox(height: 20),

                      // Date Field
                      _buildSelectField(
                        label: _localText((l) => l.dueDate),
                        value: selectedDate,
                        onTap: () => _selectDate(),
                      ),

                      SizedBox(height: 20),

                      // Account Field
                      _buildSelectField(
                        label: _localText((l) => l.account),
                        value:
                            activeAccounts.isEmpty
                                ? 'No accounts available'
                                : selectedAccount,
                        onTap:
                            activeAccounts.isEmpty
                                ? null
                                : () => _showAccountBottomSheet(),
                      ),

                      SizedBox(height: 20),

                      // Note Field
                      _buildInputField(
                        label: _localText((l) => l.note),
                        child: TextField(
                          controller: noteController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Add a note (optional)',
                            border: InputBorder.none,
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Confirm Button
            Container(
              width: double.infinity,
              margin: EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: activeAccounts.isEmpty ? null : addTrans,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isEditing ? 'Update' : _localText((l) => l.save),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    bool isSelected = index == selectedTransactionType;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTransactionType = index;
            // Update available categories based on transaction type
            availableCategories =
                index == 0 ? defaultIncomeCategories : defaultExpenseCategories;
            // Reset selected category when switching types
            selectedCategory = 'Select Category';
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.positiveGreen
                    : AppColors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isSelected ? AppColors.textDark : AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({required String label, required Widget child}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textGrey,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.grey.withOpacity(0.3)),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildSelectField({
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textGrey,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1.0,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.grey.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          value.contains('Select')
                              ? AppColors.textGrey
                              : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: AppColors.textGrey),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCategoryBottomSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16),

              Text(
                _localText((l) => l.category),
                style: theme.textTheme.titleLarge,
              ),
              SizedBox(height: 16),

              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: availableCategories.length,
                  itemBuilder: (context, index) {
                    final category = availableCategories[index];
                    final categoryColor = ColorUtils.parseColor(category.color);
                    final isSelected = selectedCategory == category.name;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedCategory = category.name;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? categoryColor?.withOpacity(0.2)
                                  : theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSelected
                                    ? categoryColor ?? theme.colorScheme.primary
                                    : theme.dividerColor,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.shadowColor.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: categoryColor?.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                IconMapping.stringToIcon(category.icon),
                                color: categoryColor,
                                size: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              IconMapping.getLocalizedCategoryNameFromCategory(
                                category,
                                AppLocalizations.of(context),
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color:
                                    isSelected
                                        ? categoryColor
                                        : theme.textTheme.bodySmall?.color,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAccountBottomSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),

              Text(
                _localText((l) => l.account),
                style: theme.textTheme.titleLarge,
              ),
              SizedBox(height: 20),

              if (listAccounts.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 48,
                        color: AppColors.textGrey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No accounts available',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textGrey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please add a money source first',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...listAccounts
                    .where((e) => e.isActive == true)
                    .map(
                      (account) => ListTile(
                        title: Text(
                          account.name,
                          style: theme.textTheme.bodyMedium,
                        ),
                        onTap: () {
                          setState(() {
                            selectedAccount = account.name;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        selectedDate = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  void _showInsufficientBalanceDialog({
    required double amount,
    required double balance,
    required String accountName,
  }) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.error_outline,
            color: theme.colorScheme.error, size: 40),
        title: const Text(
          'Lưu giao dịch thất bại',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Số dư trong ví không đủ để thực hiện giao dịch này.',
            ),
            const SizedBox(height: 12),
            Text('Ví: $accountName'),
            Text('Số dư hiện có: ${StatisticsUtils.formatAmount(balance)} VND'),
            Text('Số tiền chi: ${StatisticsUtils.formatAmount(amount)} VND'),
            const SizedBox(height: 6),
            Text(
              'Thiếu: ${StatisticsUtils.formatAmount(amount - balance)} VND',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  bool _validate(double amount, MoneySource account) {
    if (account.isActive != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tài khoản đã bị vô hiệu hoá'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    }
    // Negative amounts are never allowed — surface a clear Vietnamese
    // message that distinguishes income vs expense, since income should
    // logically never be negative.
    if (amount < 0) {
      final isIncome = selectedTransactionType == 0;
      final msg = isIncome
          ? 'Không thành công: Thu nhập không được là số âm'
          : 'Không thành công: Số tiền không được là số âm';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    }
    if (amount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Số tiền phải lớn hơn 0'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    }

    // Calculate effective balance for validation
    double effectiveBalance = account.balance;

    // If editing and same account, calculate balance after reverting old transaction
    if (isEditing &&
        editingTransaction != null &&
        oldAccount?.id == account.id) {
      if (editingTransaction!.type == TransactionType.income) {
        effectiveBalance -= editingTransaction!.amount; // Revert income
      } else {
        effectiveBalance += editingTransaction!.amount; // Revert expense
      }
    }

    // Only validate balance for expense transactions
    if (selectedTransactionType == 1 && amount > effectiveBalance) {
      _showInsufficientBalanceDialog(
        amount: amount,
        balance: effectiveBalance,
        accountName: account.name,
      );
      return false;
    }

    if (selectedCategory == 'Select Category') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
      return false;
    }

    if (selectedAccount == 'Select Account') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an account'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
      return false;
    }

    return true;
  }

  void addTrans() async {
    try {
      // Validate and parse input
      final validationResult = await _validateAndParseInput();
      if (!validationResult.isValid) {
        return;
      }

      final amount = validationResult.amount!;
      final date = validationResult.date!;
      final account = validationResult.account!;
      final type =
          selectedTransactionType == 0
              ? TransactionType.income
              : TransactionType.expense;
      final uid = context.read<UserCubit>().state.user?.uid ?? '';

      // Budget guard: for expenses, ask the user to confirm before saving a
      // transaction that would push them past the category's monthly limit.
      if (type == TransactionType.expense) {
        final proceed = await _confirmBudgetOverride(amount, date);
        if (!proceed) return;
      }

      // Create or update transaction
      if (isEditing && editingTransaction != null) {
        await _updateExistingTransaction(amount, date, account, type);
      } else {
        await _createNewTransaction(amount, date, account, type, uid);
      }

      // Update account balances
      await _updateAccountBalances(amount, account, type);
    } catch (e) {
      log('Error in addTrans: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    }
  }

  /// Ask the user whether to proceed when the new transaction would push
  /// the selected category past its configured monthly limit. Returns true
  /// if there's no limit, the limit isn't exceeded, or the user confirms.
  Future<bool> _confirmBudgetOverride(
    double addedAmount,
    DateTime date,
  ) async {
    final catState = context.read<Categoriescubit>().state;
    final matches =
        catState.categoriesExpense.where((c) => c.name == selectedCategory);
    if (matches.isEmpty) return true;
    final category = matches.first;

    final budget = await BudgetDb.instance.getByCategory(category.id);
    if (budget == null || budget.limit <= 0) return true;

    final txState = context.read<TransactionCubit>().state;
    double spentThisMonth = 0;
    txState.transactionsList.forEach((_, txs) {
      for (final t in txs) {
        if (t.type == TransactionType.expense &&
            t.categoriesId == selectedCategory &&
            t.transactionDate != null &&
            t.transactionDate!.month == date.month &&
            t.transactionDate!.year == date.year) {
          // Skip the original row when editing so we don't double-count it.
          if (isEditing && editingTransaction != null &&
              t.id == editingTransaction!.id) {
            continue;
          }
          spentThisMonth += t.amount;
        }
      }
    });
    final projected = spentThisMonth + addedAmount;
    if (projected <= budget.limit) return true;

    if (!mounted) return true;
    final theme = Theme.of(context);
    final over = projected - budget.limit;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Expanded(child: Text('Vượt hạn mức chi')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Danh mục: ${category.name}'),
            const SizedBox(height: 6),
            Text('Hạn mức: ${CurrencyFormat.vnd(budget.limit)}'),
            Text(
              'Đã chi tháng này: ${CurrencyFormat.vnd(spentThisMonth)}',
            ),
            Text('Giao dịch mới: ${CurrencyFormat.vnd(addedAmount)}'),
            const Divider(height: 20),
            Text(
              'Sau khi lưu sẽ vượt ${CurrencyFormat.vnd(over)}',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Bạn có muốn tiếp tục lưu giao dịch này không?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vẫn lưu'),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  // Helper method to validate and parse input
  Future<ValidationResult> _validateAndParseInput() async {
    // Validate amount
    if (amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter an amount')));
      return ValidationResult(isValid: false);
    }

    // Strip the thousand dots inserted by VndThousandsFormatter before parsing.
    final parsed = VndThousandsFormatter.parse(amountController.text);
    if (parsed == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Số tiền không hợp lệ')));
      return ValidationResult(isValid: false);
    }
    final amount = parsed;

    // Parse date
    DateTime date;
    if (selectedDate == 'Today') {
      date = DateTime.now();
    } else {
      try {
        final parts = selectedDate.split('/');
        date = DateTime(
          int.parse(parts[2]), // year
          int.parse(parts[1]), // month
          int.parse(parts[0]), // day
        );
      } catch (e) {
        date = DateTime.now();
      }
    }

    // Ensure account selection is valid
    if (selectedAccount == 'Select Account' ||
        selectedAccount == missingAccountPlaceholder) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Vui lòng chọn tài khoản hợp lệ')));
      return ValidationResult(isValid: false);
    }

    // Get selected account
    final account = listAccounts
        .where((e) => e.isActive == true)
        .firstWhere((e) => e.name == selectedAccount);

    // Validate input
    if (!_validate(amount, account)) {
      return ValidationResult(isValid: false);
    }

    return ValidationResult(
      isValid: true,
      amount: amount,
      date: date,
      account: account,
    );
  }

  // Helper method to create new transaction
  Future<void> _createNewTransaction(
    double amount,
    DateTime date,
    MoneySource account,
    TransactionType type,
    String uid,
  ) async {
    final transaction = Transactionsmodels(
      id: GenerateID.newID(),
      uid: uid,
      accountId: account.id ?? '',
      categoriesId: selectedCategory,
      type: type,
      amount: amount,
      note: noteController.text.trim(),
      transactionDate: date,
      createdAt: DateTime.now(),
      pendingSync: false,
    );

    await context.read<TransactionCubit>().addTransaction(transaction);
  }

  // Helper method to update existing transaction
  Future<void> _updateExistingTransaction(
    double amount,
    DateTime date,
    MoneySource account,
    TransactionType type,
  ) async {
    final updatedTransaction = Transactionsmodels(
      id: editingTransaction?.id ?? '',
      uid: editingTransaction?.uid ?? '',
      accountId: account.id ?? '',
      categoriesId: selectedCategory,
      type: type,
      amount: amount,
      note: noteController.text.trim(),
      transactionDate: date,
      createdAt: editingTransaction!.createdAt,
      pendingSync: false,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    await context.read<TransactionCubit>().updateTransaction(
      updatedTransaction,
    );
  }

  // Helper method to update account balances
  Future<void> _updateAccountBalances(
    double amount,
    MoneySource account,
    TransactionType type,
  ) async {
    if (isEditing && editingTransaction != null) {
      await _updateAccountBalancesForEdit(amount, account, type);
    } else {
      await _updateAccountBalanceForNew(amount, account, type);
    }
  }

  // Helper method to update account balances when editing
  Future<void> _updateAccountBalancesForEdit(
    double amount,
    MoneySource account,
    TransactionType type,
  ) async {
    // If there was no valid original account (e.g., it was deleted),
    // treat this like creating a new transaction impact on the selected account.
    if (oldAccount == null) {
      await _updateAccountBalanceForNew(amount, account, type);
      return;
    }

    // If account changed
    if (oldAccount?.id != account.id) {
      await _handleAccountChange(amount, account, type);
    } else {
      await _handleSameAccountUpdate(amount, account, type);
    }
  }

  // Helper method to handle account change during edit
  Future<void> _handleAccountChange(
    double amount,
    MoneySource account,
    TransactionType type,
  ) async {
    // Revert old account balance
    double oldAccBalance = oldAccount?.balance ?? 0;
    if (editingTransaction!.type == TransactionType.income) {
      oldAccBalance -= editingTransaction!.amount;
    } else {
      oldAccBalance += editingTransaction!.amount;
    }

    final newOldAccount = _createUpdatedMoneySource(oldAccount!, oldAccBalance);

    // Apply changes to new account
    double newAccBalance = account.balance;
    if (type == TransactionType.income) {
      newAccBalance += amount;
    } else {
      newAccBalance -= amount;
    }

    final newMoney = _createUpdatedMoneySource(account, newAccBalance);

    await Future.wait([
      context.read<ManageMoneyCubit>().updateAccount(newMoney),
      context.read<ManageMoneyCubit>().updateAccount(newOldAccount),
    ]);
  }

  // Helper method to handle same account update
  Future<void> _handleSameAccountUpdate(
    double amount,
    MoneySource account,
    TransactionType type,
  ) async {
    double accBalance = account.balance;
    double oldAmount = editingTransaction!.amount;
    TransactionType oldType = editingTransaction!.type;

    // Revert old transaction
    if (oldType == TransactionType.income) {
      accBalance -= oldAmount;
    } else {
      accBalance += oldAmount;
    }

    // Apply new transaction
    if (type == TransactionType.income) {
      accBalance += amount;
    } else {
      accBalance -= amount;
    }

    final newMoney = _createUpdatedMoneySource(account, accBalance);
    await context.read<ManageMoneyCubit>().updateAccount(newMoney);
  }

  // Helper method to update account balance for new transaction
  Future<void> _updateAccountBalanceForNew(
    double amount,
    MoneySource account,
    TransactionType type,
  ) async {
    // Block if account is inactive (safety net)
    if (account.isActive != true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Selected account is inactive')));
      return;
    }
    double newBalance = account.balance;
    if (type == TransactionType.income) {
      newBalance += amount;
    } else {
      newBalance -= amount;
    }

    final newMoney = _createUpdatedMoneySource(account, newBalance);
    await context.read<ManageMoneyCubit>().updateAccount(newMoney);
  }

  // Helper method to create updated MoneySource
  MoneySource _createUpdatedMoneySource(
    MoneySource original,
    double newBalance,
  ) {
    return MoneySource(
      id: original.id,
      uid: original.uid,
      name: original.name,
      balance: newBalance,
      type: original.type,
      currency: original.currency,
      iconCode: original.iconCode,
      color: original.color,
      description: original.description,
      isActive: original.isActive,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  void _showResultEvent(
    BuildContext listenerContext,
    bool isSuccess,
    BuildContext rootContext,
  ) async {
    // Show result dialog
    showDialog(
      context: listenerContext,
      barrierDismissible: false,
      builder: (context) => ResultDialogAnimation(isSuccess: isSuccess),
    );

    // Wait 2 seconds, then close dialog and navigate
    await Future.delayed(const Duration(milliseconds: 1200));

    // Close dialog if still open
    if (Navigator.of(listenerContext).canPop()) {
      Navigator.of(listenerContext).pop();
    }
    // Navigate back
    if (mounted) {
      if (fromScreen == 'wallet') {
        Navigator.of(rootContext).pop();
      } else {
        Navigator.of(
          rootContext,
        ).pushNamedAndRemoveUntil('/', ModalRoute.withName('/'));
      }
    }
  }
}
