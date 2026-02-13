import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../providers/pet_provider.dart';
import '../../services/sound_service.dart';
import 'speech_bubble.dart';
import 'fish_bone_progress.dart' hide AnimatedBuilder;
import '../../core/utils/pet_helper.dart';

/// 宠物互动卡片
class PetCard extends StatefulWidget {
  final PetState petState;
  final double budgetRatio;
  final double todayExpense;
  final VoidCallback onTap;

  const PetCard({
    super.key,
    required this.petState,
    required this.budgetRatio,
    required this.todayExpense,
    required this.onTap,
  });

  @override
  State<PetCard> createState() => _PetCardState();
}

class _PetCardState extends State<PetCard> with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  bool _isPressed = false;
  
  // 入场动画
  late AnimationController _entranceController;
  late Animation<double> _entranceScaleAnimation;

  @override
  void initState() {
    super.initState();
    // 点击弹跳动画
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    
    // 入场动画：弹起后落下静止
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    
    _entranceScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.3, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 0.9)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 25,
      ),
    ]).animate(_entranceController);
    
    // 延迟开始入场动画
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final moodColors = _getMoodGradient(widget.petState.mood);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: moodColors, // 始终使用心情渐变色（内部包含暗色适配）
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _getMoodColor(widget.petState.mood).withOpacity(isDark ? 0.2 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 主体内容
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              children: [
                // 顶部栏：昼夜图标 + 今日支出
                _buildTopBar(!isDark), // 这里传入是否为亮色
                
                const SizedBox(height: 12),
                
                // 宠物区域
                _buildPetArea(),
                
                const SizedBox(height: 16),
                
                // 鱼干进度条
                FishBoneProgress(
                  ratio: widget.budgetRatio,
                  height: 28,
                  dotColor: isDark ? Colors.white : AppColors.textPrimary,
                ),
                
                const SizedBox(height: 8),
                
                // 预算文案
                _buildBudgetText(!isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getMoodGradient(PetMood mood) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isDark) {
      // 深夜模式下，首页上方卡片背景颜色设置为和下方的消费记录颜色一样
      return AppColors.nightGradient;
    }
    
    // 浅色模式下的心情背景颜色（同步统计页逻辑）
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

  Widget _buildTopBar(bool isDaytime) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 昼夜图标
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(50),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDaytime ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                color: isDaytime ? Colors.orange : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                isDaytime ? '白天' : '晚上',
                style: TextStyle(
                  fontSize: 12,
                  color: isDaytime ? Colors.orange.shade800 : Colors.white70,
                ),
              ),
            ],
          ),
        ),
        
        // 今日支出
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(50),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.petState.type.isCustom)
                ClipOval(
                  child: Image.file(
                    File(widget.petState.type.assetPath),
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Text('🐾'),
                  ),
                )
              else
                Image.asset(
                  widget.petState.type.assetPath,
                  width: 32,
                  height: 32,
                ),
              const SizedBox(width: 4),
              Text(
                '今日 ¥${widget.todayExpense.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDaytime ? AppColors.textPrimary : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPetArea() {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _bounceController.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _bounceController.reverse();
        _handleTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _bounceController.reverse();
      },
      child: Column(
        children: [
          // 气泡文案
          SpeechBubble(message: widget.petState.message),
          
          const SizedBox(height: 8),
          
          // 宠物 (Lottie 或 Emoji) - 带入场动画
          AnimatedBuilder(
            animation: _entranceScaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _entranceScaleAnimation.value,
                child: child,
              );
            },
            child: ScaleTransition(
              scale: _bounceAnimation,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                transform: _isPressed 
                    ? Matrix4.translationValues(0, 5, 0)
                    : Matrix4.identity(),
                child: _buildPetContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetText(bool isDaytime) {
    final remaining = widget.budgetRatio;
    final percentage = (remaining * 100).toStringAsFixed(0);
    
    return Text(
      '本月口粮剩余：$percentage%',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: isDaytime ? AppColors.textPrimary.withAlpha(200) : Colors.white.withAlpha(230),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildPetContent() {
    if (widget.petState.type.isCustom) {
      return ClipOval(
        child: Image.file(
          File(widget.petState.type.assetPath),
          width: 120,
          height: 120,
          fit: BoxFit.cover, // Use cover to fill the circle
          errorBuilder: (context, error, stackTrace) => const Text('🐈', style: TextStyle(fontSize: 80)),
        ),
      );
    }
    return Image.asset(
      widget.petState.type.assetPath,
      width: 120,
      height: 120,
      fit: BoxFit.contain,
    );
  }

  // ...

  void _handleTap() {
    HapticFeedback.mediumImpact();
    
    // 播放宠物叫声 (简单映射)
    if (widget.petState.type == PetType.cat) {
      soundService.playMeow();
    } else if (widget.petState.type == PetType.dog) {
      soundService.playBark();
    } else {
      soundService.playBubble();
    }
    
    widget.onTap();
  }

  // _getPetEmoji method removed in favor of PetHelper.getPetEmoji

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

  bool _isDaytime() {
    // 如果是深色模式，强制显示为夜晚样式（深色背景 + 亮色文字）
    if (Theme.of(context).brightness == Brightness.dark) {
      return false;
    }
    final hour = DateTime.now().hour;
    return hour >= 6 && hour < 18;
  }
}
