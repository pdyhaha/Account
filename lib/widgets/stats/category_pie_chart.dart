import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/colors.dart';
import '../../providers/stats_provider.dart';

/// 分类消费饼图 - 展示各类别支出占比
/// 
/// 采用甜甜圈样式 (Donut Chart)，中心显示总支出或选中分类详情。
/// 移除底部图例，改为点击交互查看详情。
class CategoryPieChart extends ConsumerStatefulWidget {
  const CategoryPieChart({super.key});

  @override
  ConsumerState<CategoryPieChart> createState() => CategoryPieChartState();
}

class CategoryPieChartState extends ConsumerState<CategoryPieChart> 
    with SingleTickerProviderStateMixin {
  int touchedIndex = -1;
  bool _isAnimating = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // 缩放动画：从0.8缩放到1.0，只播放一次
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    // 延迟一点开始动画
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  /// 公共方法：触发缩放动画
  void triggerScaleAnimation() {
    if (mounted) {
      _scaleController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(categoryStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? AppColors.nightGradient
              : [Theme.of(context).cardColor, Theme.of(context).cardColor],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.moodHappy.withOpacity(isDark ? 0.15 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
                  color: AppColors.lavender.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🍰', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Text(
                '消费分布',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return statsAsync.when(
                data: (stats) {
                  if (stats.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildChart(stats);
                },
                loading: () => const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const Center(child: Text('加载失败')),
              );
            },
          ),
          
          const SizedBox(height: 16), // 底部留白
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🍽️',
              style: TextStyle(fontSize: 48, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 16),
            Text(
              '本月还没有消费记录哦~',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<CategoryStats> stats) {
    // 预处理数据：合并小于 5% 的分类为"其他"
    final processedStats = _processStats(stats);
    
    // 计算总支出
    final totalExpense = processedStats.fold<double>(0, (sum, item) => sum + item.amount);
    
    // 获取当前选中或默认展示的数据
    String centerTopText = '总支出';
    String centerBottomText = '¥${totalExpense.toStringAsFixed(0)}';
    Color centerColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    
    if (touchedIndex != -1 && touchedIndex < processedStats.length) {
      final selected = processedStats[touchedIndex];
      centerTopText = selected.type;
      centerBottomText = '${(selected.percentage * 100).toStringAsFixed(1)}%';
      centerColor = AppColors.getCategoryColor(selected.type);
    }

    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 饼图
          Transform.scale(
            scale: _scaleAnimation.value,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        if (event is FlTapUpEvent && touchedIndex != -1) {
                             touchedIndex = -1;
                        }
                        return;
                      }
                      final newIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      touchedIndex = newIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 4, // 扇区间隔
                centerSpaceRadius: 55, // 中心留空半径
                sections: _buildSections(processedStats),
                startDegreeOffset: 270, // 从上方开始
              ),
            ),
          ),
          
          // 2. 中心文字
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _scaleController,
              builder: (context, child) {
                 final opacity = _scaleController.value.clamp(0.0, 1.0);
                 return Opacity(
                   opacity: opacity,
                   child: child,
                 );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(
                    centerTopText,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    centerBottomText,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: centerColor,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 合并小额分类
  List<CategoryStats> _processStats(List<CategoryStats> rawStats) {
    if (rawStats.isEmpty) return [];

    // 计算总金额
    final total = rawStats.fold<double>(0, (sum, item) => sum + item.amount);
    if (total <= 0) return rawStats;

    // 阈值：5%
    const double threshold = 0.05;
    
    final List<CategoryStats> largeCategories = [];
    double smallAmount = 0;

    for (final item in rawStats) {
      if (item.percentage < threshold) {
        smallAmount += item.amount;
      } else {
        largeCategories.add(item);
      }
    }

    // 如果所有都是小额（极端情况），或者没有小额，直接返回
    if (largeCategories.isEmpty && smallAmount > 0) {
      return rawStats; // 保持原样，避免全部合并成一个"其他"
    }
    
    if (smallAmount == 0) {
      return largeCategories;
    }

    // 检查是否已存在"其他"分类
    final existingOtherIndex = largeCategories.indexWhere((e) => e.type == '其他');
    if (existingOtherIndex != -1) {
      smallAmount += largeCategories[existingOtherIndex].amount;
      largeCategories.removeAt(existingOtherIndex);
    }

    // 添加合并后的"其他"
    if (smallAmount > 0) {
      largeCategories.add(CategoryStats(
        type: '其他',
        amount: smallAmount,
        percentage: smallAmount / total,
      ));
    }
    
    // 重新排序
    largeCategories.sort((a, b) => b.amount.compareTo(a.amount));

    return largeCategories;
  }

  List<PieChartSectionData> _buildSections(List<CategoryStats> stats) {
    return stats.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final isTouched = index == touchedIndex;
      
      // 选中时放大半径
      final radius = isTouched ? 40.0 : 30.0;
      final color = AppColors.getCategoryColor(data.type);
      
      return PieChartSectionData(
        color: color,
        value: data.amount,
        title: '', // 不显示扇区内文字
        radius: radius,
        titleStyle: const TextStyle(fontSize: 0),
        badgeWidget: isTouched ? _buildBadge(data.type) : null,
        badgePositionPercentageOffset: 1.6, // 徽章位置
      );
    }).toList();
  }
  
  // 选中时显示的外部徽章（可选，增强视觉）
  Widget _buildBadge(String categoryName) {
    // 简单的圆形图标，或者可以不加，保持简洁
    // 这里我们仅做简单的装饰，比如一个小点指示
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }
}

/// 触发缩放动画的辅助函数
void triggerCategoryPieChartScaleAnimation(BuildContext context) {
  final chart = context.findAncestorStateOfType<CategoryPieChartState>();
  chart?.triggerScaleAnimation();
}