import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import 'database_provider.dart';
import 'pet_provider.dart';
import 'stats_provider.dart';

/// 当前月份预算 Provider
final currentBudgetProvider = FutureProvider<Budget?>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getCurrentMonthBudget();
});

/// 预算剩余比例 Provider (0.0 - 1.0)
final budgetRatioProvider = FutureProvider<double>((ref) async {
  final db = ref.watch(databaseProvider);
  
  final budget = await db.getCurrentMonthBudget();
  if (budget == null || budget.amount <= 0) {
    return 1.0; // 没有设置预算，默认为满
  }
  
  final spent = await db.getCurrentMonthExpenseTotal();
  final remaining = budget.amount - spent;
  final ratio = remaining / budget.amount;
  
  return ratio.clamp(0.0, 1.0);
});

/// 预算操作 Notifier
class BudgetNotifier extends StateNotifier<AsyncValue<Budget?>> {
  final AppDatabase _db;
  final Ref _ref;

  BudgetNotifier(this._db, this._ref) : super(const AsyncValue.loading()) {
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    state = const AsyncValue.loading();
    try {
      final budget = await _db.getCurrentMonthBudget();
      state = AsyncValue.data(budget);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 设置当月预算
  Future<void> setCurrentMonthBudget(double amount) async {
    try {
      final now = DateTime.now();
      await _db.setBudget(now.year, now.month, amount);
      await _loadBudget();
      _ref.invalidate(currentBudgetProvider);
      _ref.invalidate(budgetRatioProvider);
      
      // 刷新统计数据相关的 Provider
      _ref.invalidate(monthlyStatsProvider);
      
      // 预算修改后，立即刷新宠物状态和提示语
      _ref.read(petProvider.notifier).refresh();
    } catch (e) {
      rethrow;
    }
  }

  /// 刷新
  Future<void> refresh() => _loadBudget();
}

/// 预算操作 Provider
final budgetNotifierProvider =
    StateNotifierProvider<BudgetNotifier, AsyncValue<Budget?>>((ref) {
  final db = ref.watch(databaseProvider);
  return BudgetNotifier(db, ref);
});
