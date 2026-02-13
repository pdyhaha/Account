import 'package:intl/intl.dart';

/// 日期格式化工具
class DateHelper {
  DateHelper._();

  /// 格式化为相对日期（今天、昨天、具体日期）
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    final difference = today.difference(dateOnly).inDays;
    
    if (difference == 0) {
      return '今天';
    } else if (difference == 1) {
      return '昨天';
    } else if (difference == 2) {
      return '前天';
    } else if (difference < 7) {
      return _getWeekday(date.weekday);
    } else if (date.year == now.year) {
      return DateFormat('M月d日').format(date);
    } else {
      return DateFormat('yyyy年M月d日').format(date);
    }
  }

  /// 格式化时间（如 14:30）
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// 格式化完整日期时间
  static String formatDateTime(DateTime date) {
    return '${formatRelativeDate(date)} ${formatTime(date)}';
  }

  /// 获取星期几
  static String _getWeekday(int weekday) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[weekday - 1];
  }

  /// 获取月份开始时间
  static DateTime getMonthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// 获取月份结束时间
  static DateTime getMonthEnd(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59);
  }

  /// 判断是否是同一天
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
