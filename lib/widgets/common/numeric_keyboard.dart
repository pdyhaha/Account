import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/colors.dart';

/// 自定义数字键盘
class NumericKeyboard extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onClearPressed;
  final VoidCallback onDonePressed;
  final String doneLabel;

  const NumericKeyboard({
    super.key,
    required this.onKeyPressed,
    required this.onDeletePressed,
    required this.onClearPressed,
    required this.onDonePressed,
    this.doneLabel = '确认',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(['1', '2', '3']),
          _buildRow(['4', '5', '6']),
          _buildRow(['7', '8', '9']),
          _buildLastRow(),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      children: keys.map((key) => Expanded(
        child: _KeyboardButton(
          label: key,
          onPressed: () {
            HapticFeedback.lightImpact();
            onKeyPressed(key);
          },
        ),
      )).toList(),
    );
  }

  Widget _buildLastRow() {
    return Row(
      children: [
        Expanded(
          child: _KeyboardButton(
            icon: Icons.backspace_outlined,
            onPressed: () {
              HapticFeedback.lightImpact();
              onDeletePressed();
            },
            onLongPress: onClearPressed,
          ),
        ),
        Expanded(
          child: _KeyboardButton(
            label: '0',
            onPressed: () {
              HapticFeedback.lightImpact();
              onKeyPressed('0');
            },
          ),
        ),
        Expanded(
          child: _KeyboardButton(
            label: doneLabel,
            isDone: true,
            onPressed: () {
              HapticFeedback.mediumImpact();
              onDonePressed();
            },
          ),
        ),
      ],
    );
  }
}

class _KeyboardButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final bool isDone;

  const _KeyboardButton({
    this.label,
    this.icon,
    required this.onPressed,
    this.onLongPress,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      color: isDone ? AppColors.sakura : Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        onLongPress: onLongPress,
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.05),
              width: 0.5,
            ),
          ),
          child: label != null
              ? Text(
                  label!,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                    color: isDone ? Colors.white : theme.textTheme.bodyLarge?.color,
                  ),
                )
              : Icon(
                  icon,
                  size: 24,
                  color: theme.textTheme.bodyLarge?.color,
                ),
        ),
      ),
    );
  }
}
