import 'package:flutter/material.dart';

/// 萌宠账本主题色板
/// 设计理念：低饱和度马卡龙色系，温馨可爱
class AppColors {
  AppColors._();

  // ============ 马卡龙主色 ============
  
  /// 奶油黄 - 主背景色
  static const Color cream = Color(0xFFFFF8E7);
  
  /// 樱花粉 - 强调色、按钮
  static const Color sakura = Color(0xFFFFD1DC);
  
  /// 天空蓝 - 辅助色
  static const Color sky = Color(0xFFB5E2FF);
  
  /// 薄荷绿 - 次要辅助
  static const Color mint = Color(0xFFB8E6D3);
  
  /// 淡紫色 - 点缀
  static const Color lavender = Color(0xFFE8D5E8);

  // ============ 语义色 ============
  
  /// 支出红（柔和）
  static const Color expense = Color(0xFFFF8B8B);
  
  /// 收入绿（柔和）
  static const Color income = Color(0xFF7DD9A7);
  
  /// 警告橙
  static const Color warning = Color(0xFFFFB366);
  
  /// 错误红
  static const Color error = Color(0xFFFF6B6B);

  // ============ 宠物心情背景 ============
  
  /// 开心 - 暖黄（预算剩余 > 80%）
  static const Color moodHappy = Color(0xFFFFF4CC);
  
  /// 正常 - 淡蓝（预算剩余 50-80%）
  static const Color moodNormal = Color(0xFFE8F4FF);
  
  /// 担忧 - 淡橙（预算剩余 20-50%）
  static const Color moodWorry = Color(0xFFFFE8D9);
  
  /// 焦虑 - 灰蓝（预算剩余 < 20%）
  static const Color moodSad = Color(0xFFE8E8F0);

  // ============ 中性色 ============
  
  /// 主文字色
  static const Color textPrimary = Color(0xFF2D2D2D);
  
  /// 次要文字色
  static const Color textSecondary = Color(0xFF666666);
  
  /// 占位文字色
  static const Color textHint = Color(0xFFAAAAAA);
  
  /// 分割线
  static const Color divider = Color(0xFFEEEEEE);
  
  /// 卡片背景
  static const Color cardBackground = Color(0xFFFFFFFF);
  
  /// 遮罩层
  static const Color overlay = Color(0x80000000);

  // ============ 昼夜背景渐变 ============
  
  /// 白天背景渐变
  static const List<Color> dayGradient = [
    Color(0xFFFFF8E7),
    Color(0xFFFFE4B5),
  ];
  
  /// 夜晚背景渐变
  static const List<Color> nightGradient = [
    Color(0xFF2C3E50),
    Color(0xFF1A1A2E),
  ];

  // ============ 分类图标颜色 ============
  
  static const Map<String, Color> categoryColors = {
    '餐饮': Color(0xFFFF9F43),
    '交通': Color(0xFF54A0FF),
    '购物': Color(0xFFFF6B9D),
    '娱乐': Color(0xFFA55EEA),
    '生活': Color(0xFF2ED573),
    '医疗': Color(0xFFFF4757),
    '美妆护肤': Color(0xFFFF9FF3),
    '人情社交': Color(0xFFFFD93D),
    '旅行': Color(0xFF1DD1A1),
    '其他': Color(0xFF747D8C),
    // 收入分类
    '工资': Color(0xFF2ED573),
    '红包': Color(0xFFFF6B6B),
    '报销': Color(0xFF54A0FF),
  };

  /// 获取分类颜色
  static Color getCategoryColor(String type) {
    return categoryColors[type] ?? categoryColors['其他']!;
  }
}
