import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import 'database_provider.dart';
import 'stats_provider.dart';
import 'pet_provider.dart';
import '../services/widget_service.dart';

/// 账单列表 Provider
final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllTransactions();
});

/// 今日账单 Provider
final todayTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getTodayTransactions();
});

/// 本月账单 Provider
final currentMonthTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getCurrentMonthTransactions();
});

/// 今日支出总额 Provider
final todayExpenseTotalProvider = FutureProvider<double>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getTodayExpenseTotal();
});

/// 本月支出总额 Provider
final currentMonthExpenseTotalProvider = FutureProvider<double>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getCurrentMonthExpenseTotal();
});

/// 最近一条账单 Provider
final latestTransactionProvider = FutureProvider<Transaction?>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getLatestTransaction();
});

/// 账单操作 Notifier
class TransactionNotifier extends StateNotifier<AsyncValue<List<Transaction>>> {
  final AppDatabase _db;
  final Ref _ref;

  TransactionNotifier(this._db, this._ref) : super(const AsyncValue.loading()) {
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    // 只有在没有数据时才显示 Loading，避免刷新时闪烁
    if (state.value == null) {
      state = const AsyncValue.loading();
    }
    
    try {
      final transactions = await _db.getAllTransactions();
      state = AsyncValue.data(transactions);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _invalidateStats() {
    _ref.invalidate(todayTransactionsProvider);
    _ref.invalidate(todayExpenseTotalProvider);
    _ref.invalidate(currentMonthTransactionsProvider);
    _ref.invalidate(latestTransactionProvider);
    
    // 自动同步流会处理统计页面的刷新
    
    // 刷新宠物心情（因为它依赖预算/支出）
    _ref.read(petProvider.notifier).refresh();
    
    // 同步到小组件 (refresh 内部也会同步，但这里确保所有数据都已刷新)
    Future.microtask(() {
      WidgetService.forceUpdateWidget(_ref);
    });
  }

  /// 添加账单
  Future<void> addTransaction({
    required double amount,
    required bool isExpense,
    required String category,
    required String categoryType,
    required DateTime datetime,
    String? note,
    String? emoji,
  }) async {
    try {
      // 插入账单
      await _db.insertTransaction(TransactionsCompanion.insert(
        amount: amount,
        isExpense: Value(isExpense),
        category: category,
        categoryType: categoryType,
        datetime: datetime,
        note: Value(note),
        emoji: Value(emoji),
      ));

      // 更新分类使用次数
      await _db.getOrCreateCategory(category, categoryType, isExpense);

      // 刷新列表
      await _loadTransactions();
      
      // 刷新相关 Provider
      _invalidateStats();
    } catch (e) {
      rethrow;
    }
  }

  /// 删除账单
  Future<void> deleteTransaction(int id) async {
    try {
      await _db.deleteTransaction(id);
      await _loadTransactions();
      
      _invalidateStats();
    } catch (e) {
      rethrow;
    }
  }

  /// 更新账单
  Future<void> updateTransaction(Transaction transaction) async {
    try {
      await _db.updateTransaction(transaction);
      await _loadTransactions();
      
      _invalidateStats();
    } catch (e) {
      rethrow;
    }
  }

  /// 刷新
  Future<void> refresh() => _loadTransactions();
}

/// 账单操作 Provider
final transactionNotifierProvider =
    StateNotifierProvider<TransactionNotifier, AsyncValue<List<Transaction>>>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionNotifier(db, ref);
});
