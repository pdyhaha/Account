import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/colors.dart';
import '../widgets/transaction/add_transaction_sheet.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/widget_service.dart';
import '../providers/pet_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/database_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/budget_provider.dart';
import '../core/utils/pet_helper.dart';

/// 主框架 - 包含底部导航栏
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 优化：只进行一次刷新，无需多次重复调用
      _refreshData();
    }
  }

  void _refreshData() {
    print('MainShell: refreshing data...');
    // 强制刷新所有关键数据 Provider
    ref.invalidate(transactionNotifierProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(monthlyStatsProvider);
    ref.invalidate(todayExpenseTotalProvider);
    
    // 同时也刷新预算相关，因支出变化会影响预算比例
    ref.invalidate(currentBudgetProvider);
    ref.invalidate(budgetRatioProvider);
    
    // 最后刷新宠物（它依赖以上数据）
    ref.invalidate(petProvider);
    
    // 刷新完成后，强制同步一次小组件，确保数值最新
    _updateWidget(ref);
  }

  @override
  Widget build(BuildContext context) {
    // 监听状态变化更新 Widget
    _listenForWidgetUpdates(ref);

    final currentPath = GoRouterState.of(context).uri.path;
    final showFab = currentPath == '/';

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: const _BottomNavBar(),
      floatingActionButton: showFab
          ? Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 8),
              child: const _MainFAB(),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _listenForWidgetUpdates(WidgetRef ref) {
    ref.listen(themeProvider, (_, __) {
      _updateWidget(ref);
    });
    ref.listen(petProvider, (_, next) {
      _updateWidget(ref);
    });
    // 监听月度统计变化
    ref.listen(monthlyStatsProvider, (_, __) {
      _updateWidget(ref);
    });
    // 监听今日支出变化
    ref.listen(todayExpenseTotalProvider, (_, __) {
      _updateWidget(ref);
    });
  }

  void _updateWidget(WidgetRef ref) async {
    final petState = ref.read(petProvider);
    final statsAsync = ref.read(monthlyStatsProvider);
    final todayExpenseAsync = ref.read(todayExpenseTotalProvider);
    final themeMode = ref.read(themeProvider);
    
    // 判断当前是否应该是深色模式
    bool isDark = false;
    if (themeMode == AppThemeMode.dark) {
      isDark = true;
    } else if (themeMode == AppThemeMode.auto) {
      final hour = DateTime.now().hour;
      if (hour >= 23 || hour < 7) {
        isDark = true;
      }
    }

    double todayExpense = 0.0;
    double monthExpense = 0.0;
    
    // 优先使用 provider 数据
    if (todayExpenseAsync.hasValue) {
      todayExpense = todayExpenseAsync.value ?? 0.0;
    }
    if (statsAsync.hasValue) {
      monthExpense = statsAsync.value?.totalExpense ?? 0.0;
    }
    
    // 如果 provider 数据不可用，从数据库直接获取
    if (todayExpense == 0.0 || monthExpense == 0.0) {
      try {
        final db = ref.read(databaseProvider);
        if (todayExpense == 0.0) {
          todayExpense = await db.getTodayExpenseTotal();
        }
        if (monthExpense == 0.0) {
          monthExpense = await db.getCurrentMonthExpenseTotal();
        }
      } catch (e) {
        print('Failed to get expense from database: $e');
      }
    }
    
    await WidgetService.updateWidget(
      petImagePath: petState.type.assetPath,
      petType: petState.type.name,
      petMessage: petState.message,
      todayExpense: todayExpense,
      monthExpense: monthExpense,
      isDark: isDark,
    );
  }
}

/// 中央浮动按钮 - 支持长按滑动选择
class _MainFAB extends StatefulWidget {
  const _MainFAB({super.key});

  @override
  State<_MainFAB> createState() => _MainFABState();
}

class _MainFABState extends State<_MainFAB> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  // 选项高亮状态
  String? _highlightedOption;
  
  // 用于获取按钮位置的 Key
  final GlobalKey _voiceKey = GlobalKey();
  final GlobalKey _manualKey = GlobalKey();
  
  // 透明度控制
  double _opacity = 1.0;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    // 启动3秒定时器
    _startInactivityTimer();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _inactivityTimer?.cancel();
    super.dispose();
  }
  
  // 启动未使用定时器
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isExpanded) {
        setState(() {
          _opacity = 0.7;
        });
      }
    });
  }
  
  // 重置定时器（用户交互时调用）
  void _resetInactivityTimer() {
    setState(() {
      _opacity = 1.0;
    });
    _startInactivityTimer();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        _resetInactivityTimer(); // 用户交互，重置定时器
        HapticFeedback.heavyImpact();
        setState(() => _isExpanded = true);
      },
      onLongPressMoveUpdate: (details) {
        _checkDragCollision(details.globalPosition);
      },
      onLongPressEnd: (details) {
        _handleDragEnd();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 展开的选项按钮
          if (_isExpanded) ...[
            _buildOptionButton(
              key: _voiceKey,
              icon: Icons.mic,
              label: '语音记账',
              color: AppColors.sky,
              isHighlighted: _highlightedOption == 'voice',
              onTap: () {
                _resetInactivityTimer(); // 用户交互，重置定时器
                _selectOption('voice');
              },
            ),
            const SizedBox(height: 12),
            _buildOptionButton(
              key: _manualKey,
              icon: Icons.edit,
              label: '手动记账',
              color: AppColors.mint,
              isHighlighted: _highlightedOption == 'manual',
              onTap: () {
                _resetInactivityTimer(); // 用户交互，重置定时器
                _selectOption('manual');
              },
            ),
            const SizedBox(height: 12),
          ],
          
          // 主按钮
          AnimatedOpacity(
            opacity: _isExpanded ? 1.0 : _opacity,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: () {
                _resetInactivityTimer(); // 用户交互，重置定时器
                _handleTap();
              },
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isExpanded ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary : AppColors.sakura,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
              BoxShadow(
                color: (_isExpanded ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary : AppColors.sakura)
                    .withAlpha(100),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isExpanded ? Icons.close : Icons.add,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
    required bool isHighlighted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(isHighlighted ? 150 : 80),
              blurRadius: isHighlighted ? 16 : 8,
              spreadRadius: isHighlighted ? 2 : 0,
              offset: const Offset(0, 2),
            ),
          ],
          border: isHighlighted 
            ? Border.all(color: Colors.white, width: 2) 
            : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkDragCollision(Offset globalPosition) {
    // 获取渲染对象
    final voiceBox = _voiceKey.currentContext?.findRenderObject() as RenderBox?;
    final manualBox = _manualKey.currentContext?.findRenderObject() as RenderBox?;

    String? newHighlight;

    // 检测语音按钮
    if (voiceBox != null) {
      final position = voiceBox.localToGlobal(Offset.zero);
      final rect = position & voiceBox.size;
      // 扩大感应区域：左右各扩大 40，上下扩大 10
      final hitRect = Rect.fromLTRB(
        rect.left - 40, 
        rect.top - 10, 
        rect.right + 40, 
        rect.bottom + 10
      );
      
      if (hitRect.contains(globalPosition)) {
        newHighlight = 'voice';
      }
    }

    // 检测手动按钮（如果还没选中语音）
    if (newHighlight == null && manualBox != null) {
      final position = manualBox.localToGlobal(Offset.zero);
      final rect = position & manualBox.size;
      // 同样扩大感应区域
      final hitRect = Rect.fromLTRB(
        rect.left - 40, 
        rect.top - 10, 
        rect.right + 40, 
        rect.bottom + 10
      );
      
      if (hitRect.contains(globalPosition)) {
        newHighlight = 'manual';
      }
    }

    // 状态改变时触发震动
    if (_highlightedOption != newHighlight) {
      if (newHighlight != null) {
        // 选中时轻微震动反馈
        HapticFeedback.selectionClick();
      }
      setState(() => _highlightedOption = newHighlight);
    }
  }

  void _handleDragEnd() {
    if (_highlightedOption != null) {
      // 成功选中，执行操作
      final option = _highlightedOption!;
      _selectOption(option);
    } else {
      // 未选中任何项，关闭菜单
      setState(() {
        _isExpanded = false;
        _highlightedOption = null;
      });
    }
  }

  void _selectOption(String option) {
    // 先给予反馈
    HapticFeedback.mediumImpact();
    
    // 关闭菜单
    setState(() {
      _isExpanded = false;
      _highlightedOption = null;
    });

    // 延迟极短时间后跳转，避免视觉突兀
    Future.microtask(() {
      if (!mounted) return;
      if (option == 'voice') {
        context.push('/voice');
      } else if (option == 'manual') {
        showAddTransactionSheet(context);
      }
    });
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    if (_isExpanded) {
      setState(() => _isExpanded = false);
    } else {
      // 单击默认打开手动记账
      showAddTransactionSheet(context);
    }
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: '首页',
                isSelected: currentPath == '/',
                onTap: () => context.go('/'),
              ),
              _NavItem(
                icon: Icons.pie_chart_rounded,
                label: '统计',
                isSelected: currentPath == '/stats',
                onTap: () => context.go('/stats'),
              ),
              _NavItem(
                icon: Icons.settings_rounded,
                label: '设置',
                isSelected: currentPath == '/settings',
                onTap: () => context.go('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unselectedColor = Theme.of(context).bottomNavigationBarTheme.unselectedItemColor ?? AppColors.textHint;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.sakura : unselectedColor,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.sakura : unselectedColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
