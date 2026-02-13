import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import 'database_provider.dart';

/// 当前选中的统计月份
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// 监听数据库变动的流 (由数据操作触发)
final transactionUpdateProvider = StreamProvider<void>((ref) {
  final db = ref.watch(databaseProvider);
  // 监听 transactions 表的任何变化
  return db.select(db.transactions).watch().map((_) => null);
});

/// 分类统计数据
class CategoryStats {
  final String type;
  final double amount;
  final double percentage;

  const CategoryStats({
    required this.type,
    required this.amount,
    required this.percentage,
  });
}

/// 月度统计数据
class MonthlyStats {
  final double totalExpense;
  final double totalIncome;
  final double budget;
  final double budgetRatio;
  final List<CategoryStats> categoryBreakdown;
  final int transactionCount;
  final DateTime month; // 新增月份字段

  const MonthlyStats({
    required this.totalExpense,
    required this.totalIncome,
    required this.budget,
    required this.budgetRatio,
    required this.categoryBreakdown,
    required this.transactionCount,
    required this.month,
  });

  /// 预算剩余
  double get remaining => budget - totalExpense;

  /// 日均消费 (如果不是当前月，除以该月总天数)
  double get dailyAverage {
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final daysPassed = isCurrentMonth ? now.day : daysInMonth;
    
    return daysPassed > 0 ? totalExpense / daysPassed : 0;
  }

  /// 预计月底总消费 (仅当前月有效)
  double get projectedMonthlyExpense {
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    
    if (!isCurrentMonth) return totalExpense;
    
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return dailyAverage * daysInMonth;
  }
}

/// 指定月份分类支出统计 Provider
final categoryExpenseProvider = FutureProvider<Map<String, double>>((ref) async {
  // 核心：监听数据库流，一旦有变动就重新执行
  ref.watch(transactionUpdateProvider);
  
  final db = ref.watch(databaseProvider);
  final month = ref.watch(selectedMonthProvider);
  
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  
  return db.getExpenseByType(start: start, end: end);
});

/// 指定月份分类统计（带百分比）Provider
final categoryStatsProvider = FutureProvider<List<CategoryStats>>((ref) async {
  final expenseMap = await ref.watch(categoryExpenseProvider.future);
  
  if (expenseMap.isEmpty) return [];
  
  final total = expenseMap.values.fold(0.0, (sum, val) => sum + val);
  
  // 按金额排序
  final sorted = expenseMap.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  
  return sorted.map((e) => CategoryStats(
    type: e.key,
    amount: e.value,
    percentage: total > 0 ? e.value / total : 0,
  )).toList();
});

/// 指定月份收入总额 Provider
final currentMonthIncomeTotalProvider = FutureProvider<double>((ref) async {
  ref.watch(transactionUpdateProvider);
  
  final db = ref.watch(databaseProvider);
  final month = ref.watch(selectedMonthProvider);
  
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  
  final transactions = await db.getTransactionsByDateRange(start, end);
  double total = 0.0;
  for (final t in transactions) {
    if (!t.isExpense) total += t.amount;
  }
  return total;
});

/// 指定月份综合统计 Provider
final monthlyStatsProvider = FutureProvider<MonthlyStats>((ref) async {
  // 监听更新标识
  ref.watch(transactionUpdateProvider);
  
  final db = ref.watch(databaseProvider);
  final month = ref.watch(selectedMonthProvider);
  
  // 获取起止时间
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  
  // 并行获取数据
  final results = await Future.wait([
    ref.watch(categoryExpenseProvider.future), // 复用上面的 provider 计算支出
    ref.watch(currentMonthIncomeTotalProvider.future),
    db.getBudget(month.year, month.month),
    ref.watch(categoryStatsProvider.future),
    db.getTransactionsByDateRange(start, end),
  ]);
  
  final expenseMap = results[0] as Map<String, double>;
  final income = results[1] as double;
  final budget = results[2] as Budget?;
  final categories = results[3] as List<CategoryStats>;
  final transactions = results[4] as List<Transaction>;
  
  final expense = expenseMap.values.fold(0.0, (sum, val) => sum + val);
  
  final budgetAmount = budget?.amount ?? 0;
  final ratio = budgetAmount > 0 
    ? ((budgetAmount - expense) / budgetAmount).clamp(0.0, 1.0)
    : 1.0;
  
  return MonthlyStats(
    totalExpense: expense,
    totalIncome: income,
    budget: budgetAmount,
    budgetRatio: ratio,
    categoryBreakdown: categories,
    transactionCount: transactions.length,
    month: month,
  );
});

/// 消费排行榜数据 (Top 5)
final spendingRankingProvider = FutureProvider<List<CategoryStats>>((ref) async {
  final stats = await ref.watch(categoryStatsProvider.future);
  return stats.take(5).toList();
});

/// 今日 vs 昨日消费对比 (保持不变，因为今日对比通常只关注当下)
final dailyComparisonProvider = FutureProvider<Map<String, double>>((ref) async {
  ref.watch(transactionUpdateProvider);
  
  final db = ref.watch(databaseProvider);
  
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
  
  final todayTransactions = await db.getTodayTransactions();
  final yesterdayTransactions = await db.getTransactionsByDateRange(
    yesterdayStart, 
    todayStart,
  );
  
  double todayTotal = 0;
  double yesterdayTotal = 0;
  
  for (final t in todayTransactions) {
    if (t.isExpense) todayTotal += t.amount;
  }
  for (final t in yesterdayTransactions) {
    if (t.isExpense) yesterdayTotal += t.amount;
  }
  
  return {
    'today': todayTotal,
    'yesterday': yesterdayTotal,
    'change': todayTotal - yesterdayTotal,
  };
});

/// 本周每日消费趋势 (保持不变，关注近期趋势)
final weeklyTrendProvider = FutureProvider<List<double>>((ref) async {
  ref.watch(transactionUpdateProvider);
  
  final db = ref.watch(databaseProvider);
  
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  
  List<double> dailyTotals = [];
  
  for (int i = 0; i < 7; i++) {
    final dayStart = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
    final dayEnd = dayStart.add(const Duration(days: 1));
    
    if (dayStart.isAfter(now)) {
      dailyTotals.add(0);
      continue;
    }
    
    final transactions = await db.getTransactionsByDateRange(dayStart, dayEnd);
    double total = 0;
    for (final t in transactions) {
      if (t.isExpense) total += t.amount;
    }
    dailyTotals.add(total);
  }
  
  return dailyTotals;
});
