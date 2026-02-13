import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../providers/database_provider.dart';
import '../../data/database/app_database.dart';
import '../../widgets/transaction/transaction_list.dart';

class CategoryDetailPage extends ConsumerWidget {
  final String categoryType;
  final double totalAmount;

  const CategoryDetailPage({
    super.key,
    required this.categoryType,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(categoryTransactionsProvider(categoryType));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(categoryType),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 顶部汇总
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.nightGradient
                    : [Theme.of(context).cardColor, Theme.of(context).cardColor],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text('本月支出', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(
                  '¥${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.expense,
                  ),
                ),
              ],
            ),
          ),
          
          // 列表
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) => CustomScrollView(
                slivers: [
                  TransactionList(transactions: transactions),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('加载失败: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

/// 特定分类本月账单 Provider (Family Provider)
final categoryTransactionsProvider = FutureProvider.family<List<Transaction>, String>((ref, categoryType) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 1);
  
  // 我们需要在 AppDatabase 中加一个查询方法，或者在 Provider 里过滤
  // 简单起见，我们在 AppDatabase 里加一个查询
  // 但为了不反复修改 db 文件，我们在这里获取本月所有账单然后过滤
  // 性能上对于个人记账来说完全没问题
  
  final allMonthTransactions = await db.getCurrentMonthTransactions();
  return allMonthTransactions.where((t) => t.categoryType == categoryType).toList();
});
