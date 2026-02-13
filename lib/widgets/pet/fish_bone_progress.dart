import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// 吃豆人进度条 - 形象化展示预算消耗
class FishBoneProgress extends StatefulWidget {
  /// 剩余比例 (0.0 - 1.0)
  final double ratio;
  
  /// 进度条高度
  final double height;
  
  /// 是否显示动画
  final bool animate;

  /// 豆子颜色
  final Color? dotColor;

  const FishBoneProgress({
    super.key,
    required this.ratio,
    this.height = 24,
    this.animate = true,
    this.dotColor,
  });

  @override
  State<FishBoneProgress> createState() => _FishBoneProgressState();
}

class _FishBoneProgressState extends State<FishBoneProgress>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pacmanController;
  late Animation<double> _progressAnimation;
  double _currentRatio = 0;

  @override
  void initState() {
    super.initState();
    
    // 进度动画控制器
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // 吃豆人张嘴动画控制器
    _pacmanController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    )..repeat(reverse: true);
    
    _progressAnimation = Tween<double>(
      begin: 0,
      end: widget.ratio,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));

    if (widget.animate) {
      _progressController.forward();
    } else {
      _currentRatio = widget.ratio;
    }
  }

  @override
  void didUpdateWidget(FishBoneProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ratio != widget.ratio) {
      _progressAnimation = Tween<double>(
        begin: _currentRatio,
        end: widget.ratio,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOutCubic,
      ));
      _progressController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pacmanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        _currentRatio = _progressAnimation.value;
        return _buildProgressBar(_currentRatio);
      },
    );
  }

  Widget _buildProgressBar(double ratio) {
    final safeRatio = ratio.clamp(0.0, 1.0);
    final color = _getColorForRatio(safeRatio);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: (widget.dotColor ?? Colors.white).withAlpha(77),
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          child: Stack(
            children: [
              // 背景豆子
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.height * 0.3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(8, (index) {
                      final beanPosition = index / 7.0;
                      // 如果豆子位置在吃豆人右边（已花费区域），说明被吃掉了
                      // 左边是剩余的，豆子存在；右边是花掉的，豆子被吃
                      final isEaten = beanPosition > safeRatio;
                      return _Dot(
                        isEaten: isEaten,
                        size: widget.height * 0.2,
                        color: widget.dotColor,
                      );
                    }),
                  ),
                ),
              ),
              
              // 吃豆人
              AnimatedBuilder(
                animation: _pacmanController,
                builder: (context, child) {
                  // 吃豆人位置：剩余比例决定位置，safeRatio越大越靠右（从左往右移动）
                  final pacmanX = safeRatio * (constraints.maxWidth - widget.height);
                  return Positioned(
                    left: pacmanX,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Transform.flip(
                        flipX: true, // 嘴巴朝左，准备吃左边的豆子
                        child: _PacmanCharacter(
                          isOpen: _pacmanController.value > 0.5,
                          size: widget.height * 0.7,
                          isHungry: safeRatio <= 0.1,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // 进度填充效果
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: safeRatio,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withAlpha(80),
                        color.withAlpha(40),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(widget.height / 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Color _getColorForRatio(double ratio) {
    if (ratio > 0.8) return AppColors.income;
    if (ratio > 0.5) return AppColors.sky;
    if (ratio > 0.2) return AppColors.warning;
    return AppColors.expense;
  }
}

/// 单个豆子装饰
class _Dot extends StatelessWidget {
  final bool isEaten;
  final double size;
  final Color? color;

  const _Dot({
    required this.isEaten,
    required this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = color ?? Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isEaten 
            ? Colors.transparent 
            : dotColor.withAlpha(200),
        boxShadow: isEaten ? null : [
          BoxShadow(
            color: dotColor.withAlpha(100),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// 吃豆人角色组件
class _PacmanCharacter extends StatelessWidget {
  final bool isOpen;
  final double size;
  final bool isHungry;

  const _PacmanCharacter({
    required this.isOpen,
    required this.size,
    required this.isHungry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      child: Stack(
        children: [
          // 吃豆人身体
          Container(
            decoration: BoxDecoration(
              color: isHungry ? Colors.orange : Colors.yellow,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isHungry ? Colors.orange : Colors.yellow).withAlpha(100),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          
          // 嘴巴
          Positioned.fill(
            child: CustomPaint(
              painter: _PacmanMouthPainter(
                isOpen: isOpen,
              ),
            ),
          ),
          
          // 眼睛
          Positioned(
            top: size * 0.2,
            right: size * 0.25,
            child: Container(
              width: size * 0.12,
              height: size * 0.12,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 吃豆人嘴巴绘制器
class _PacmanMouthPainter extends CustomPainter {
  final bool isOpen;

  _PacmanMouthPainter({required this.isOpen});

  @override
  void paint(Canvas canvas, Size size) {
    final mouthPaint = Paint()
      ..color = Colors.white.withAlpha(200)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    if (isOpen) {
      // 张开的嘴巴（大三角形缺口）
      final mouthPath = Path();
      mouthPath.moveTo(center.dx, center.dy);
      mouthPath.lineTo(
        center.dx + radius * 0.9,
        center.dy - radius * 0.8,
      );
      mouthPath.lineTo(
        center.dx + radius * 0.9,
        center.dy + radius * 0.8,
      );
      mouthPath.close();

      canvas.drawPath(mouthPath, mouthPaint);
    } else {
      // 闭上的嘴巴（小三角形缺口）
      final mouthPath = Path();
      mouthPath.moveTo(center.dx, center.dy);
      mouthPath.lineTo(
        center.dx + radius * 0.9,
        center.dy - radius * 0.3,
      );
      mouthPath.lineTo(
        center.dx + radius * 0.9,
        center.dy + radius * 0.3,
      );
      mouthPath.close();

      canvas.drawPath(mouthPath, mouthPaint);
    }
  }

  @override
  bool shouldRepaint(_PacmanMouthPainter oldDelegate) {
    return oldDelegate.isOpen != isOpen;
  }
}