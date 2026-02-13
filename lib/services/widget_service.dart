import 'package:home_widget/home_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/budget_provider.dart';
import '../providers/pet_provider.dart';
import '../providers/database_provider.dart';
import '../providers/theme_provider.dart';

import '../services/pet_service.dart';

class WidgetService {
  static const String _groupId = 'group.pet_ledger_widget';
  static const String _androidWidgetName = 'PetWidget';

  /// 更新小组件数据
  static Future<void> updateWidget({
    required String petImagePath,
    required String petType,
    required String petMessage,
    required double todayExpense,
    required double monthExpense,
    required bool isDark,
    bool isCustom = false,
    String? customImagePath,
  }) async {
    try {
      // 如果是自定义宠物，小组件使用对应的预设代用品
      final PetType type = PetType.presets.firstWhere(
        (p) => p.name == petType,
        orElse: () {
          // 如果找不到对应的预设（说明是自定义的），使用 hash 映射一个预设
          final index = petType.hashCode.abs() % PetType.presets.length;
          return PetType.presets[index];
        }
      );

      // 获取代用品的本地路径
      final String? localPath = await PetService.getLocalPetPath(type);

      if (localPath != null) {
        print('WidgetService: Saving to widget (group: $_groupId) - pet_image_path: $localPath');
        await HomeWidget.saveWidgetData<String>('pet_image_path', localPath);
      } else {
        print('WidgetService: Image path is null, cannot save to widget');
      }
      
      await HomeWidget.saveWidgetData<String>('pet_type', type.name);
      await HomeWidget.saveWidgetData<String>('pet_message', petMessage);
      await HomeWidget.saveWidgetData<String>('today_expense', '¥${todayExpense.toStringAsFixed(0)}');
      await HomeWidget.saveWidgetData<String>('month_expense', '¥${monthExpense.toStringAsFixed(0)}');
      await HomeWidget.saveWidgetData<int>('is_dark', isDark ? 1 : 0);
      
      // 额外的保险：同时保存一份到 SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        if (localPath != null) await prefs.setString('pet_image_path', localPath);
        await prefs.setString('pet_type', type.name);
        await prefs.setString('pet_message', petMessage);
        await prefs.setString('today_expense', '¥${todayExpense.toStringAsFixed(0)}');
        await prefs.setString('month_expense', '¥${monthExpense.toStringAsFixed(0)}');
        await prefs.setBool('is_dark', isDark);
      } catch (e) {
        print('WidgetService: Save to SharedPreferences fallback failed: $e');
      }
      
      final result = await HomeWidget.updateWidget(
        name: _androidWidgetName,
        androidName: _androidWidgetName,
      );
      print('WidgetService: updateWidget result: $result');
    } catch (e) {
      print('Widget update failed: $e');
    }
  }
  
  /// 强制刷新小组件（从数据库获取最新数据）
  static Future<void> forceUpdateWidget(Ref ref, {PetState? petState, String? customImagePath}) async {
    try {
      final PetState currentPetState = petState ?? ref.read(petProvider);
      final db = ref.read(databaseProvider);
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

      // 获取开销数据 (独立捕获异常，防止 DB 失败影响宠物更新)
      double todayExpense = 0;
      double monthExpense = 0;
      try {
        todayExpense = await db.getTodayExpenseTotal();
        monthExpense = await db.getCurrentMonthExpenseTotal();
      } catch (e) {
        print('WidgetService: Fetch expense failed (using default 0): $e');
      }

      await updateWidget(
        petImagePath: currentPetState.type.assetPath,
        petType: currentPetState.type.name,
        petMessage: currentPetState.message,
        todayExpense: todayExpense,
        monthExpense: monthExpense,
        isDark: isDark,
        isCustom: currentPetState.type.isCustom,
        customImagePath: customImagePath,
      );
    } catch (e) {
      print('Force widget update failed: $e');
    }
  }
}

/// 监听状态变化并更新 Widget 的 Provider
final widgetUpdateProvider = Provider<void>((ref) {
  final petState = ref.watch(petProvider);
  final budgetRatioAsync = ref.watch(budgetRatioProvider);
  final currentBudgetAsync = ref.watch(currentBudgetProvider);
  
  // 计算余额 (这里简单估算，最好有一个 explicit balance provider)
  // 这里暂时用一个假设值或者需要计算真实余额
  // 实际上我们需要 currentMonthExpenseTotalProvider
  // 简化起见，我们只更新表情
  
  // 由于这里不能异步等待 expense provider，我们在 TransactionNotifier 里手动触发更新
});
