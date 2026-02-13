import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../providers/stats_provider.dart';
import '../../pages/stats/category_detail_page.dart';

/// 剁手排行榜 - Top 5 消费分类
class SpendingRankings extends ConsumerWidget {
  const SpendingRankings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(spendingRankingProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? AppColors.nightGradient
              : [Theme.of(context).cardColor, Theme.of(context).cardColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.moodHappy.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.sakura.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🏆', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Text(
                '剁手排行榜',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sakura.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '本月 Top5',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.sakura,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 排行榜列表
          rankingAsync.when(
            data: (rankings) {
              if (rankings.isEmpty) {
                return _buildEmptyState(context);
              }
              return Column(
                children: rankings.asMap().entries.map((entry) {
                  return _buildRankingItem(
                    context: context,
                    rank: entry.key + 1,
                    stats: entry.value,
                    maxAmount: rankings.first.amount,
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Center(child: Text('加载失败')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '😸',
              style: TextStyle(fontSize: 36, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 8),
            Text(
              '本月还没有消费哦~',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingItem({
    required BuildContext context,
    required int rank,
    required CategoryStats stats,
    required double maxAmount,
  }) {
    final color = AppColors.getCategoryColor(stats.type);
    final progress = maxAmount > 0 ? stats.amount / maxAmount : 0.0;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryDetailPage(
              categoryType: stats.type,
              totalAmount: stats.amount,
            ),
          ),
        );
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // 排名
            SizedBox(
              width: 32,
              child: _buildRankBadge(rank, context),
            ),
            const SizedBox(width: 12),
            
            // 分类和进度条
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stats.type,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '¥${stats.amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 进度条
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        height: 8,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color.withOpacity(0.7),
                                  color,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank, BuildContext context) {
    String emoji;
    Color bgColor;
    
    switch (rank) {
      case 1:
        emoji = '🥇';
        bgColor = const Color(0xFFFFD700);
        break;
      case 2:
        emoji = '🥈';
        bgColor = const Color(0xFFC0C0C0);
        break;
      case 3:
        emoji = '🥉';
        bgColor = const Color(0xFFCD7F32);
        break;
      default:
        emoji = '$rank';
        bgColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.1);
    }
    
    if (rank <= 3) {
      return Text(emoji, style: const TextStyle(fontSize: 24));
    }
    
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          emoji,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
