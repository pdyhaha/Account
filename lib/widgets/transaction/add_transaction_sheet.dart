import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/date_helper.dart';
import '../../providers/transaction_provider.dart';
import '../../data/database/app_database.dart';
import 'amount_keyboard.dart';
import '../../core/utils/dialog_helper.dart';

/// 手动记账/编辑账单弹窗
class AddTransactionSheet extends ConsumerStatefulWidget {
  final Transaction? transaction;

  const AddTransactionSheet({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  int _step = 0;
  String _amount = '';
  bool _isExpense = true;
  String? _selectedType;
  String _note = '';
  late DateTime _selectedDateTime;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  final bool _isTyping = false;
  final List<String> _smartSuggestions = [];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final t = widget.transaction!;
      // 修复编辑时金额显示错误 (例如 20 -> 2)
      _amount = t.amount.toStringAsFixed(2);
      if (_amount.endsWith('.00')) {
        _amount = _amount.substring(0, _amount.length - 3);
      } else if (_amount.contains('.') && _amount.endsWith('0')) {
        _amount = _amount.substring(0, _amount.length - 1);
      }
      _isExpense = t.isExpense;
      _selectedType = t.categoryType;
      _note = t.note ?? '';
      _noteController.text = _note;
      _amountController.text = _amount;
      _selectedDateTime = t.datetime;
    } else {
      _selectedDateTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Flexible(
          child: SingleChildScrollView(
            child: _buildContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.transaction == null ? '记一笔' : '编辑账单',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_step) {
      case 0:
        return _buildAmountStep();
      case 1:
        return _buildCategoryStep();
      case 2:
        return _buildNoteStep();
      case 3:
        return _buildConfirmStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildAmountStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '输入金额',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildExpenseToggle(),
          const SizedBox(height: 16),
          AmountKeyboard(
            amount: _amount,
            onAmountChanged: (value) {
              setState(() => _amount = value);
            },
            onConfirm: () {
              if (_amount.isNotEmpty) {
                setState(() => _step = 1);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isExpense = true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isExpense ? AppColors.expense : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '支出',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isExpense ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isExpense = false);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isExpense ? AppColors.income : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '收入',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isExpense ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryStep() {
    final types = _isExpense
        ? CategoryConstants.expenseTypes
        : CategoryConstants.incomeTypes;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '选择分类',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types.map((type) {
              final isSelected = _selectedType == type.name;
              final color = AppColors.getCategoryColor(type.name);
              
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedType = type.name);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withAlpha(30) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : AppColors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        type.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? color : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 0),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('上一步', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedType != null
                      ? () => setState(() => _step = 2)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.expense,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.expense.withAlpha(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('下一步', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold).copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoteStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '消费时间',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildDateTimePicker(),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            style: const TextStyle(color: AppColors.textPrimary),
            maxLength: 50,
            decoration: InputDecoration(
              hintText: '记录一下这笔消费吧~',
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.sakura, width: 2),
              ),
            ),
            onChanged: (value) {
              setState(() => _note = value);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 1),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('上一步', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _step = 3),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.expense,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('确认', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold).copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep() {
    final amount = double.tryParse(_amount) ?? 0.0;
    final categoryEmoji = CategoryConstants.getEmoji(_selectedType ?? '其他');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('金额', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary)),
                    Text(
                      '¥${amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: _isExpense ? AppColors.expense : AppColors.income,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('分类', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary)),
                    Text(
                      '$categoryEmoji ${_selectedType ?? '其他'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('时间', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary)),
                    Text(
                      DateHelper.formatDateTime(_selectedDateTime),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                if (_note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('备注', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary)),
                      Expanded(
                        child: Text(
                          _note,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 2),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('返回', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.expense,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isExpense ? '记账' : '入账',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold).copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        _pickDateTime();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              DateHelper.formatDateTime(_selectedDateTime),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final initialDate = _selectedDateTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || date == null) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (!mounted) {
      return;
    }
    if (time == null) {
      setState(() {
        _selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    } else {
      setState(() {
        _selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  void _saveTransaction() async {
    final amount = double.tryParse(_amount) ?? 0.0;
    if (amount <= 0) return;
    if (_selectedType == null) return;

    final categoryEmoji = CategoryConstants.getEmoji(_selectedType!);

    if (widget.transaction == null) {
      await ref.read(transactionNotifierProvider.notifier).addTransaction(
        amount: amount,
        isExpense: _isExpense,
        category: _selectedType!,
        categoryType: _selectedType!,
        datetime: _selectedDateTime,
        note: _note.isNotEmpty ? _note : null,
        emoji: categoryEmoji,
      );
    } else {
      final existing = widget.transaction!;
      final updatedTransaction = Transaction(
        id: existing.id,
        amount: amount,
        isExpense: _isExpense,
        category: _selectedType!,
        categoryType: _selectedType!,
        datetime: _selectedDateTime,
        note: _note.isNotEmpty ? _note : existing.note,
        emoji: categoryEmoji,
        createdAt: existing.createdAt,
      );
      await ref.read(transactionNotifierProvider.notifier).updateTransaction(updatedTransaction);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}

/// 显示添加/编辑账单弹窗
void showAddTransactionSheet(BuildContext context, {Transaction? transaction}) {
  DialogHelper.showButlerBottomSheet(
    context: context,
    heightFactor: 0.85,
    child: AddTransactionSheet(transaction: transaction),
  );
}
