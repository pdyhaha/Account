import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'app.dart';
import 'pages/voice/voice_overlay_page.dart';
import 'core/theme/app_theme.dart';

import 'package:workmanager/workmanager.dart';
import 'services/background_service.dart' as bg;

import 'services/pet_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化宠物资源
  await PetService.initializePetAssets();
  
  // 初始化 WorkManager
  try {
    await Workmanager().initialize(
      bg.callbackDispatcher,
      isInDebugMode: false,
    );
  } catch (e, st) {
    debugPrint('Workmanager initialize failed: $e');
    debugPrint('$st');
  }
  
  // 注册定时任务
  try {
    await _scheduleDailyReport();
  } catch (e, st) {
    debugPrint('Workmanager register daily report task failed: $e');
    debugPrint('$st');
  }
  
  // 监听 Widget 点击
  HomeWidget.setAppGroupId('group.pet_ledger_widget'); 
  HomeWidget.registerInteractivityCallback(backgroundCallback);
  
  runApp(
    const ProviderScope(
      child: PetLedgerApp(),
    ),
  );
}

Future<void> _scheduleDailyReport() async {
  final now = DateTime.now();
  var target = DateTime(now.year, now.month, now.day, 22, 0);
  
  if (now.isAfter(target)) {
    target = target.add(const Duration(days: 1));
  }
  
  final initialDelay = target.difference(now);
  
  await Workmanager().registerPeriodicTask(
    "daily_report",
    bg.kDailyReportTask,
    frequency: const Duration(hours: 24),
    initialDelay: initialDelay,
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );
}


@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri?.host == 'voice') {
  }
}

/// 独立的桌面语音浮层入口点，避免与主应用引擎冲突/重复初始化
@pragma('vm:entry-point')
void voiceMain() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: VoiceOverlayApp(),
    ),
  );

  // 在后台悄悄拉取资源
  PetService.initializePetAssets();
}

/// 仅包含语音浮层的简化应用结构
class VoiceOverlayApp extends StatelessWidget {
  const VoiceOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '语音记账',
      theme: AppTheme.light.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        // 关键：使背景透明
        canvasColor: Colors.transparent,
      ),
      darkTheme: AppTheme.dark.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
      ),
      // 强制透明背景
      color: Colors.transparent,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: child,
        );
      },
      home: const VoiceOverlayPage(isStandalone: true),
    );
  }
}
