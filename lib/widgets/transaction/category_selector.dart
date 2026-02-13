import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/colors.dart';
import '../../core/constants/categories.dart';

/// 分类选择器
class CategorySelector extends StatelessWidget {
  final bool isExpense;
  final String? selectedType;
  final ValueChanged<String> onTypeSelected;
  final ValueChanged<bool> onExpenseToggle;

  const CategorySelector({
    super.key,
    required this.isExpense,
    required this.selectedType,
    required this.onTypeSelected,
    required this.onExpenseToggle,
  });

  @override
  Widget build(BuildContext context) {
    final types = isExpense
        ? CategoryConstants.expenseTypes
        : CategoryConstants.incomeTypes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 支出/收入切换
        _buildToggle(),
        
        const SizedBox(height: 16),
        
        // 分类网格
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: types.map((type) {
            final isSelected = selectedType == type.name;
            return _CategoryChip(
              name: type.name,
              emoji: type.emoji,
              isSelected: isSelected,
              color: AppColors.getCategoryColor(type.name),
              onTap: () {
                HapticFeedback.selectionClick();
                onTypeSelected(type.name);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            label: '支出',
            isSelected: isExpense,
            color: AppColors.expense,
            onTap: () {
              if (!isExpense) {
                HapticFeedback.selectionClick();
                onExpenseToggle(true);
              }
            },
          ),
          _ToggleButton(
            label: '收入',
            isSelected: !isExpense,
            color: AppColors.income,
            onTap: () {
              if (isExpense) {
                HapticFeedback.selectionClick();
                onExpenseToggle(false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String name;
  final String emoji;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.name,
    required this.emoji,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(30) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
