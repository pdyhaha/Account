import 'package:flutter/material.dart';
import 'colors.dart';

/// 萌宠账本文字样式
/// 设计理念：圆润可爱，易读性强
class AppTextStyles {
  AppTextStyles._();

  // ============ 字体家族 ============
  // 使用系统默认字体，后续可替换为站酷快乐体等可爱字体
  static const String fontFamily = 'sans-serif';

  // ============ 标题样式 ============
  
  /// 大标题 - 用于页面标题
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// 中标题 - 用于卡片标题
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// 小标题 - 用于列表分组标题
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// 标题中 - 用于卡片内标题、对话框标题
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // ============ 正文样式 ============
  
  /// 正文大
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  /// 正文中
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  /// 正文小
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // ============ 金额样式 ============
  
  /// 大金额 - 用于总结余展示
  static const TextStyle amountLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.2,
  );
  
  /// 中金额 - 用于列表项
  static const TextStyle amountMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.2,
  );
  
  /// 支出金额
  static TextStyle get expenseAmount => amountMedium.copyWith(
    color: AppColors.expense,
  );
  
  /// 收入金额
  static TextStyle get incomeAmount => amountMedium.copyWith(
    color: AppColors.income,
  );

  // ============ 特殊样式 ============
  
  /// 宠物气泡文案
  static const TextStyle petBubble = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  /// 按钮文字
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1.2,
  );
  
  /// 标签文字
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.2,
  );
  
  /// 提示文字
  static TextStyle hint = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textHint,
    height: 1.4,
  );

  // ============ 日期时间样式 ============
  
  /// 日期分组标题（今天、昨天）
  static const TextStyle dateGroup = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 1.3,
  );
  
  /// 时间显示
  static const TextStyle time = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textHint,
    height: 1.2,
  );
}
