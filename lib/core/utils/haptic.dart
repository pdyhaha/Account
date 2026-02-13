import 'package:flutter/services.dart';

/// 震动反馈工具
class HapticHelper {
  HapticHelper._();

  /// 轻微震动
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// 中等震动
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// 重度震动
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// 选择反馈
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// 成功反馈
  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// 错误反馈
  static void error() {
    HapticFeedback.heavyImpact();
  }
}
