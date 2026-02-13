import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';

/// 自定义数字键盘
class AmountKeyboard extends StatelessWidget {
  final String amount;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const AmountKeyboard({
    super.key,
    required this.amount,
    required this.onAmountChanged,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动指示器
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 金额显示
            _buildAmountDisplay(context),
            
            const SizedBox(height: 20),
            
            // 数字键盘
            _buildKeypadGrid(),
            
            const SizedBox(height: 16),
            
            // 确认按钮
            _buildConfirmButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountDisplay(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '¥',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount.isEmpty ? '0' : amount,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadGrid() {
    final keys = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      '.', '0', '⌫',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        return _KeyButton(
          label: keys[index],
          onTap: () => _handleKeyTap(keys[index]),
        );
      },
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    final hasAmount = amount.isNotEmpty && double.tryParse(amount) != null && double.parse(amount) > 0;
    
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: hasAmount ? onConfirm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: hasAmount ? AppColors.expense : AppColors.expense.withAlpha(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          '确认记账',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold).copyWith(
            color: hasAmount ? Colors.white : AppColors.textHint,
          ),
        ),
      ),
    );
  }

  void _handleKeyTap(String key) {
    HapticFeedback.lightImpact();
    
    String newAmount = amount;
    
    if (key == '⌫') {
      // 删除
      if (newAmount.isNotEmpty) {
        newAmount = newAmount.substring(0, newAmount.length - 1);
      }
    } else if (key == '.') {
      // 小数点
      if (!newAmount.contains('.') && newAmount.isNotEmpty) {
        newAmount = '$newAmount.';
      } else if (newAmount.isEmpty) {
        newAmount = '0.';
      }
    } else {
      // 数字
      if (newAmount == '0' && key != '.') {
        newAmount = key;
      } else if (newAmount.contains('.')) {
        // 小数点后最多两位
        final parts = newAmount.split('.');
        if (parts.length < 2 || parts[1].length < 2) {
          newAmount = '$newAmount$key';
        }
      } else if (newAmount.length < 8) {
        // 整数部分最多8位
        newAmount = '$newAmount$key';
      }
    }
    
    onAmountChanged(newAmount);
  }
}

/// 单个按键
class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeyButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBackspace = label == '⌫';
    
    return Material(
      color: isBackspace
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.divider,
              width: 1,
            ),
          ),
          child: Center(
            child: isBackspace
                ? Icon(
                    Icons.backspace_outlined,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary,
                    size: 24,
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
