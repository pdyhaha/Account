import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/date_helper.dart';
import '../../data/database/app_database.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/transaction/add_transaction_sheet.dart';

/// 账单流水列表
class TransactionList extends ConsumerWidget {
  final List<Transaction> transactions;

  const TransactionList({super.key, required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📝', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              Text(
                '还没有记录哦',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '点击麦克风开始记账吧',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 按日期分组
    final grouped = _groupByDate(transactions);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = grouped.entries.elementAt(index);
          return _DateGroup(
            dateLabel: entry.key,
            transactions: entry.value,
          );
        },
        childCount: grouped.length,
      ),
    );
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final Map<String, List<Transaction>> grouped = {};
    
    for (final t in transactions) {
      final label = DateHelper.formatRelativeDate(t.datetime);
      grouped.putIfAbsent(label, () => []).add(t);
    }
    
    return grouped;
  }
}

/// 日期分组组件
class _DateGroup extends StatelessWidget {
  final String dateLabel;
  final List<Transaction> transactions;

  const _DateGroup({
    super.key,
    required this.dateLabel,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? AppColors.nightGradient
              : [Theme.of(context).cardColor, Theme.of(context).cardColor],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.moodHappy.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(dateLabel, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          ...transactions.map((t) => _TransactionItem(transaction: t)),
        ],
      ),
    );
  }
}

/// 交易记录项组件
class _TransactionItem extends ConsumerWidget {
  final Transaction transaction;

  const _TransactionItem({super.key, required this.transaction});

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 根据分类获取 emoji (这里假设有这个辅助方法，或者用默认的)
    // 修正：CategoryConstants.getEmoji 应该返回 String
    final emoji = CategoryConstants.getEmoji(transaction.category);
    
    return Dismissible(
      key: ValueKey(transaction.id), // 使用 ValueKey 更稳定
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // 左滑删除 - 确认
          return await _showDeleteConfirmDialog(context, ref);
        } else if (direction == DismissDirection.startToEnd) {
          // 右滑修改 - 触发逻辑后恢复原状 (不 dismiss)
          showAddTransactionSheet(context, transaction: transaction);
          return false; 
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          ref.read(transactionNotifierProvider.notifier).deleteTransaction(transaction.id);
        }
      },
      // 背景：右滑修改 (Start to End)
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4), // 必须与 child margin 一致
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AppColors.sky,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.edit, color: Colors.white),
            SizedBox(width: 8),
            Text('修改', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      // 次要背景：左滑删除 (End to Start)
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 4), // 必须与 child margin 一致
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('删除', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, // 显式给个背景色，防止透明导致视觉问题
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            showAddTransactionSheet(context, transaction: transaction);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 分类图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.getCategoryColor(transaction.category).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 交易信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.category,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (transaction.note != null && transaction.note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            transaction.note!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // 金额和时间
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!transaction.isExpense)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Text('⭐', style: TextStyle(fontSize: 10)),
                          ),
                        Text(
                          '${transaction.isExpense ? '-' : '+'}${transaction.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: transaction.isExpense ? AppColors.expense : AppColors.income,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateHelper.formatTime(transaction.datetime),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除?'),
        content: const Text('这条记录被删掉后就找不回来咯~'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('手滑了'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }
}