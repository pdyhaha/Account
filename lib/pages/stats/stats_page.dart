import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/stats/mood_dashboard.dart';
import '../../widgets/stats/category_pie_chart.dart';
import '../../widgets/stats/spending_rankings.dart';
import '../../widgets/stats/wish_pool.dart';

/// 统计页面 - "宠物心情日记"
/// 展示消费分析、图表、排行榜和储蓄目标
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  // 用于控制饼图动画.
  final GlobalKey<CategoryPieChartState> _pieChartKey = GlobalKey();
  // 记录是否已在顶部，用于触发"回到顶部"的动画
  bool _isAtTop = true;

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final isCurrentMonth = selectedMonth.year == now.year && selectedMonth.month == now.month;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollUpdateNotification) {
            // 只有当滑动到顶部 (pixels <= 0) 且之前不在顶部时，才触发动画
            final isAtTop = scrollNotification.metrics.pixels <= 0;
            
            if (isAtTop && !_isAtTop) {
               _pieChartKey.currentState?.triggerScaleAnimation();
            }
            
            // 更新状态
            _isAtTop = isAtTop;
          }
          return false;
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 顶部 App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bar_chart_rounded,
                      size: 28,
                      color: AppColors.sakura,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('yyyy年M月').format(selectedMonth),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.sakura.withOpacity(0.3),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                // 回到本月
                if (!isCurrentMonth)
                  IconButton(
                    onPressed: () {
                      ref.read(selectedMonthProvider.notifier).state = DateTime(now.year, now.month);
                    },
                    icon: const Icon(Icons.today_rounded, color: AppColors.sakura),
                    tooltip: '回到本月',
                  ),
                  
                // 月份选择器
                IconButton(
                  onPressed: () => _showMonthPicker(context, selectedMonth),
                  icon: Icon(
                    Icons.calendar_month_rounded,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            
            // 内容
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // 心情仪表盘
                  const RepaintBoundary(
                    child: MoodDashboard(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 消费分布饼图 (传入 Key)
                  RepaintBoundary(
                    child: CategoryPieChart(key: _pieChartKey),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 剁手排行榜
                  const RepaintBoundary(
                    child: SpendingRankings(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 许愿池 - 储蓄目标
                  const RepaintBoundary(
                    child: WishPool(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 快捷数据卡片
                  _buildQuickStats(context),
                  
                  // 底部留白
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMonthPicker(BuildContext context, DateTime current) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: 500,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('选择月份', style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: () {
                      final now = DateTime.now();
                      ref.read(selectedMonthProvider.notifier).state = DateTime(now.year, now.month);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.today_rounded, size: 18),
                    label: const Text('回到本月'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.sakura),
                  ),
                ],
              ),
            ),
            
            // 年月选择列表
            Expanded(
              child: ListView.builder(
                itemCount: 5, // 显示最近5年
                itemBuilder: (context, index) {
                  final year = DateTime.now().year - index;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Text(
                            '$year年', 
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold, 
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary
                            ),
                          ),
                        ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          childAspectRatio: 1.2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, monthIndex) {
                          final month = monthIndex + 1;
                          final isSelected = current.year == year && current.month == month;
                          final isCurrentMonth = DateTime.now().year == year && DateTime.now().month == month;
                          
                          return InkWell(
                            onTap: () {
                              ref.read(selectedMonthProvider.notifier).state = DateTime(year, month);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected 
                                  ? AppColors.sakura 
                                  : (isCurrentMonth ? AppColors.sakura.withOpacity(0.1) : null),
                                borderRadius: BorderRadius.circular(12),
                                border: isCurrentMonth && !isSelected 
                                  ? Border.all(color: AppColors.sakura) 
                                  : null,
                              ),
                              child: Text(
                                '$month月',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                                  fontWeight: isSelected || isCurrentMonth ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 快捷统计卡片
  Widget _buildQuickStats(BuildContext context) {
    final statsAsync = ref.watch(monthlyStatsProvider);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickStatCard(
              context: context,
              icon: '📅',
              title: '本月预算',
              value: statsAsync.value?.budget.toStringAsFixed(0) ?? '-',
              subtitle: '剩余: ${(statsAsync.value?.remaining ?? 0).toStringAsFixed(0)}',
              color: AppColors.sky,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickStatCard(
              context: context,
              icon: '📝',
              title: '记账笔数',
              value: statsAsync.value?.transactionCount.toString() ?? '-',
              subtitle: '总计: ${(statsAsync.value?.totalExpense ?? 0).toStringAsFixed(0)}',
              color: AppColors.lavender,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard({
    required BuildContext context,
    required String icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    // ... helper method logic if needed, but wait, the original file had it.
    // I need to include it or rewrite it. The original file had it.
    // I should generate the full file content including this helper.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? null
            : Theme.of(context).cardColor,
        gradient: Theme.of(context).brightness == Brightness.dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.nightGradient,
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8), // 使用主题色加深
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}