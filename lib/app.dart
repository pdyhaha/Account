import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';
import 'providers/theme_provider.dart';
import 'providers/theme_mask_provider.dart';
import 'routes/app_router.dart';
import 'services/native_channel_service.dart';
import 'providers/transaction_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/pet_provider.dart';

/// 萌宠账本应用
class PetLedgerApp extends ConsumerStatefulWidget {
  const PetLedgerApp({super.key});

  @override
  ConsumerState<PetLedgerApp> createState() => _PetLedgerAppState();
}

class _PetLedgerAppState extends ConsumerState<PetLedgerApp> with WidgetsBindingObserver {
  Timer? _themeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestNotificationPermission();
    _startThemeTimer();
    
    // 初始化原生通道服务（处理小组件路由）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NativeChannelService.init(appRouter);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 当应用回到前台，强制刷新所有核心数据
      // 解决小组件记录数据后 App 内不更新的问题
      _refreshAllData();
    }
  }

  void _refreshAllData() {
    debugPrint('App resumed, refreshing all data...');
    // 刷新交易相关
    ref.invalidate(transactionsProvider);
    ref.invalidate(todayTransactionsProvider);
    ref.invalidate(todayExpenseTotalProvider);
    ref.invalidate(currentMonthTransactionsProvider);
    ref.invalidate(currentMonthExpenseTotalProvider);
    ref.invalidate(latestTransactionProvider);
    
    // 刷新统计页相关
    ref.invalidate(categoryExpenseProvider);
    ref.invalidate(categoryStatsProvider);
    ref.invalidate(monthlyStatsProvider);
    ref.invalidate(currentMonthIncomeTotalProvider);
    ref.invalidate(spendingRankingProvider);
    ref.invalidate(dailyComparisonProvider);
    ref.invalidate(weeklyTrendProvider);
    
    // 基础设置相关
    ref.invalidate(currentBudgetProvider);
    ref.invalidate(budgetRatioProvider);
    
    // 宠物状态
    ref.read(petProvider.notifier).refresh();
  }

  void _startThemeTimer() {
    // 每分钟检查一次时间以更新主题（仅当处于 Auto 模式时需要，但一直运行也无妨，
    // 因为 setState 会触发重绘，re-eval _getThemeMode）
    _themeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  ThemeMode _getThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.auto:
        final hour = DateTime.now().hour;
        // 23:00 - 07:00 使用暗色模式
        if (hour >= 23 || hour < 7) {
          return ThemeMode.dark;
        }
        return ThemeMode.light;
    }
  }

  void _requestNotificationPermission() async {
    await Permission.notification.request();
  }


  @override
  Widget build(BuildContext context) {
    // 监听主题变化，延时关闭遮罩
    ref.listen(themeProvider, (previous, next) {
      if (previous != next) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          ref.read(themeMaskProvider.notifier).state = false;
        });
      }
    });

    final themeMode = ref.watch(themeProvider);
    final isMaskShowing = ref.watch(themeMaskProvider);
    final activeThemeMode = _getThemeMode(themeMode);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          MaterialApp.router(
            key: ValueKey(activeThemeMode), // 强制重建整个应用以解决主题切换崩溃问题
            title: '动物记账🧾',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: activeThemeMode,
            themeAnimationStyle: AnimationStyle.noAnimation, // 缓解插值报错
            routerConfig: appRouter,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'), // 中文
              Locale('en', 'US'), // 英文
            ],
          ),
          
          // 全屏遮罩层 - 位于最顶层，遮盖包括状态栏在内的所有内容
          if (isMaskShowing)
            Positioned.fill(
              // 关键：不使用动画构建器，直接同步渲染实色背景，防止第一帧出现透明度导致的红色闪烁漏出
              child: Container(
                color: activeThemeMode == ThemeMode.dark ? const Color(0xFF121212) : Colors.white,
                child: Material(
                  color: Colors.transparent,
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.85, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOutCubic,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: activeThemeMode == ThemeMode.dark 
                                  ? Colors.white.withValues(alpha: 0.05) 
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(
                                color: AppColors.sakura.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: const CircularProgressIndicator(
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.sakura),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            '正在为您切换主题...',
                            style: TextStyle(
                              color: activeThemeMode == ThemeMode.dark ? Colors.white70 : Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
