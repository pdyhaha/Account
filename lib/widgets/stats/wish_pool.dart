import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../providers/stats_provider.dart';

/// 许愿池 - 储蓄目标和进度展示
class WishPool extends ConsumerWidget {
  const WishPool({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(monthlyStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? AppColors.nightGradient
              : [const Color(0xFFE8F5E9), const Color(0xFFB2DFDB)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.mint.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 背景装饰
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.savings_outlined,
              size: 120,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          
          // 内容
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('🌊', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '许愿池',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '存钱小目标',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // 储蓄统计
                statsAsync.when(
                  data: (stats) => _buildSavingsContent(stats, context),
                  loading: () => const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const Center(child: Text('加载失败')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsContent(MonthlyStats stats, BuildContext context) {
    final isSaving = stats.totalIncome > stats.totalExpense;
    final netSaving = stats.totalIncome - stats.totalExpense;
    
    return Column(
      children: [
        // 主储蓄显示
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // 储蓄罐动画效果
              _buildPiggyBank(isSaving, netSaving.abs()),
              const SizedBox(width: 16),
              
              // 数据
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSaving ? '本月净存款' : '本月超支',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isSaving ? '+' : '-'}¥${netSaving.abs().toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: isSaving ? AppColors.income : AppColors.expense,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSaving 
                        ? '继续加油，宠物为你骄傲！'
                        : '下个月要注意控制哦~',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // 预测提示
        if (stats.projectedMonthlyExpense > 0) _buildProjection(stats, context),
      ],
    );
  }

  Widget _buildPiggyBank(bool isSaving, double amount) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: isSaving 
          ? AppColors.income.withOpacity(0.2)
          : AppColors.expense.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          isSaving ? '🐷' : '😿',
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }

  Widget _buildProjection(MonthlyStats stats, BuildContext context) {
    final willOverBudget = stats.budget > 0 && 
        stats.projectedMonthlyExpense > stats.budget;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: willOverBudget 
          ? AppColors.warning.withOpacity(0.2)
          : AppColors.mint.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            willOverBudget ? '⚠️' : '📊',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              willOverBudget
                ? '按当前速度，月底预计消费 ¥${stats.projectedMonthlyExpense.toStringAsFixed(0)}，可能超预算哦'
                : '日均消费 ¥${stats.dailyAverage.toStringAsFixed(0)}，预计月底消费 ¥${stats.projectedMonthlyExpense.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: willOverBudget 
                  ? AppColors.warning
                  : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}