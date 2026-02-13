import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/home/home_page.dart';
import '../pages/stats/stats_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/voice/voice_overlay_page.dart';
import '../pages/butler/butler_chat_page.dart';
import 'main_shell.dart';

/// 应用路由配置
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // 主框架（带底部导航栏）
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomePage(),
          ),
        ),
        GoRoute(
          path: '/stats',
          name: 'stats',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: StatsPage(),
          ),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsPage(),
          ),
        ),
      ],
    ),
    // 语音浮窗（全屏覆盖）
    GoRoute(
      path: '/voice',
      name: 'voice',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const VoiceOverlayPage(),
        opaque: false,
        barrierColor: Colors.black54,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    ),
  ],
);
