import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/date_helper.dart';
import '../../services/llm_service.dart';

/// 收银小票确认卡
class ReceiptCard extends StatefulWidget {
  final LLMResult result;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final Function(LLMResult) onEdit;

  const ReceiptCard({
    super.key,
    required this.result,
    required this.onConfirm,
    required this.onCancel,
    required this.onEdit,
  });

  @override
  State<ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends State<ReceiptCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  late TextEditingController _amountController;
  late TextEditingController _noteController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _amountController = TextEditingController(
      text: widget.result.amount?.toStringAsFixed(2) ?? '',
    );
    _noteController = TextEditingController(
      text: widget.result.event ?? '',
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 小票头部
              _buildHeader(),
              
              // 虚线分割
              _buildDashedDivider(),
              
              // 小票内容
              _buildContent(),
              
              // 虚线分割
              _buildDashedDivider(),
              
              // 操作按钮
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🧾', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Text(
            '记账小票',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(
          30,
          (index) => Expanded(
            child: Container(
              height: 1,
              color: index.isEven ? AppColors.divider : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final result = widget.result;
    final emoji = CategoryConstants.getEmoji(result.type ?? '其他');
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 时间
          _buildRow(
            icon: '⏰',
            label: '时间',
            value: result.datetime != null
                ? _formatDateTime(result.datetime!)
                : '刚才',
            onTap: null,
          ),
          
          const SizedBox(height: 12),
          
          // 分类
          _buildRow(
            icon: emoji,
            label: '分类',
            value: '${result.type ?? "其他"} / ${result.category ?? "未知"}',
            onTap: null,
          ),
          
          const SizedBox(height: 12),
          
          // 备注
          _buildRow(
            icon: '📝',
            label: '备注',
            value: result.event ?? '',
            isEditable: true,
            controller: _noteController,
            onTap: () => setState(() => _isEditing = true),
          ),
          
          const SizedBox(height: 16),
          
          // 金额（大字）
          _buildAmountDisplay(),
        ],
      ),
    );
  }

  Widget _buildRow({
    required String icon,
    required String label,
    required String value,
    bool isEditable = false,
    TextEditingController? controller,
    VoidCallback? onTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
          SizedBox(
          width: 50,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: isEditable && _isEditing
              ? TextField(
                  controller: controller,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: UnderlineInputBorder(),
                  ),
                  onSubmitted: (_) => setState(() => _isEditing = false),
                )
              : GestureDetector(
                  onTap: onTap,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      decoration: isEditable
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      decorationStyle: TextDecorationStyle.dashed,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAmountDisplay() {
    final isExpense = widget.result.isExpense;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isExpense ? '🐾' : '⭐',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 8),
          Text(
            '¥',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isExpense ? AppColors.expense : AppColors.income,
            ),
          ),
          const SizedBox(width: 4),
          _isEditing
              ? SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: isExpense ? AppColors.expense : AppColors.income,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: UnderlineInputBorder(),
                    ),
                    onSubmitted: (_) => setState(() => _isEditing = false),
                  ),
                )
              : GestureDetector(
                  onTap: () => setState(() => _isEditing = true),
                  child: Text(
                    widget.result.amount?.toStringAsFixed(2) ?? '0.00',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: isExpense ? AppColors.expense : AppColors.income,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // 取消按钮
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onCancel();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: AppColors.divider),
              ),
              child: Text(
                '取消',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold).copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // 确认按钮
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: AppColors.expense.withAlpha(100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('✓', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text('盖章确认', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String datetime) {
    if (datetime == 'now' || datetime == 'today') {
      return DateHelper.formatDateTime(DateTime.now());
    }
    try {
      final dt = DateTime.parse(datetime);
      return DateHelper.formatDateTime(dt);
    } catch (_) {
      return datetime;
    }
  }
}
