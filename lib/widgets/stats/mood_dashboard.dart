import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../providers/pet_provider.dart';
import '../../providers/stats_provider.dart';
import '../../core/utils/pet_helper.dart';

/// 宠物心情仪表盘 - 展示本月预算消耗和宠物状态
class MoodDashboard extends ConsumerStatefulWidget {
  const MoodDashboard({super.key});

  @override
  ConsumerState<MoodDashboard> createState() => _MoodDashboardState();
}

class _MoodDashboardState extends ConsumerState<MoodDashboard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _petAnimController;
  late Animation<double> _petScaleAnimation;

  @override
  void initState() {
    super.initState();
    _petAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _petScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 0.9)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_petAnimController);
    
    // 延迟开始动画
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _petAnimController.forward();
    });
  }

  @override
  void dispose() {
    _petAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petState = ref.watch(petProvider);
    final statsAsync = ref.watch(monthlyStatsProvider);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? AppColors.nightGradient
              : _getMoodGradient(petState.mood, context),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _getMoodColor(petState.mood).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和心情
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '宠物心情日记',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getMoodDescription(petState.mood),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              _buildMoodEmoji(petState.type, petState.mood),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 预算进度
          statsAsync.when(
            data: (stats) => _buildBudgetProgress(stats, context),
            loading: () => const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Text('加载失败'),
          ),
          
          const SizedBox(height: 16),
          
          // 宠物寄语
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (petState.type.isCustom)
                  Image.file(
                    File(petState.type.assetPath),
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Text('🐾'),
                  )
                else
                  Image.asset(
                    petState.type.assetPath,
                    width: 32,
                    height: 32,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    petState.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetProgress(MonthlyStats stats, BuildContext context) {
    // ... (rest of method)
    final hasNoBudget = stats.budget <= 0;
    
    return Column(
      children: [
        // 进度条
        Stack(
          children: [
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              height: 12,
              width: hasNoBudget ? double.infinity : null,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasNoBudget 
                    ? [AppColors.mint, AppColors.sky]
                    : _getProgressGradient(stats.budgetRatio),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: hasNoBudget 
                ? null 
                : FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: stats.budgetRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getProgressGradient(stats.budgetRatio),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // 数据展示
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatItem(
              label: '本月支出',
              value: '¥${stats.totalExpense.toStringAsFixed(0)}',
              color: AppColors.expense,
              context: context,
            ),
            _buildStatItem(
              label: hasNoBudget ? '未设预算' : '预算剩余',
              value: hasNoBudget ? '-' : '¥${stats.remaining.toStringAsFixed(0)}',
              color: stats.remaining >= 0 ? AppColors.income : AppColors.expense,
              context: context,
            ),
            _buildStatItem(
              label: '本月收入',
              value: '¥${stats.totalIncome.toStringAsFixed(0)}',
              color: AppColors.income,
              context: context,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
    required BuildContext context,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodEmoji(PetType type, PetMood mood) {
    return AnimatedBuilder(
      animation: _petScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _petScaleAnimation.value,
          child: child,
        );
      },
      child: type.isCustom
          ? ClipOval(
              child: Image.file(
                File(type.assetPath),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Text('🐾'),
              ),
            )
          : Image.asset(
              PetHelper.getPetImage(type, mood),
              width: 60,
              height: 60,
              fit: BoxFit.contain,
            ),
    );
  }

  // _getMoodEmoji method removed as it is no longer used
  // _getPetTypeEmoji method removed as it can be replaced by type.emoji direct access

  String _getMoodDescription(PetMood mood) {
    switch (mood) {
      case PetMood.happy:
        return '宠物心情大好！继续保持~';
      case PetMood.normal:
        return '宠物状态不错哦';
      case PetMood.worry:
        return '宠物有点担心...';
      case PetMood.sad:
        return '宠物有点emo了...';
    }
  }

  Color _getMoodColor(PetMood mood) {
    switch (mood) {
      case PetMood.happy:
        return AppColors.moodHappy;
      case PetMood.normal:
        return AppColors.moodNormal;
      case PetMood.worry:
        return AppColors.moodWorry;
      case PetMood.sad:
        return AppColors.moodSad;
    }
  }

  List<Color> _getMoodGradient(PetMood mood, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isDark) {
      // 暗黑模式下的颜色
      switch (mood) {
        case PetMood.happy:
          return [const Color(0xFF2D3B2D), const Color(0xFF1B2A1B)];
        case PetMood.normal:
          return [const Color(0xFF2D3B4D), const Color(0xFF1B293A)];
        case PetMood.worry:
          return [const Color(0xFF4D3B2D), const Color(0xFF3A291B)];
        case PetMood.sad:
          return [const Color(0xFF3D3D4D), const Color(0xFF2A2A3A)];
      }
    }
    
    // 浅色模式下的颜色
    switch (mood) {
      case PetMood.happy:
        return [const Color(0xFFFFF8E1), const Color(0xFFFFECB3)];
      case PetMood.normal:
        return [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)];
      case PetMood.worry:
        return [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)];
      case PetMood.sad:
        return [const Color(0xFFECEFF1), const Color(0xFFCFD8DC)];
    }
  }

  List<Color> _getProgressGradient(double ratio) {
    if (ratio > 0.5) {
      return [AppColors.mint, AppColors.income];
    } else if (ratio > 0.2) {
      return [AppColors.warning, const Color(0xFFFFD54F)];
    } else {
      return [AppColors.expense, const Color(0xFFFF8A80)];
    }
  }
}
