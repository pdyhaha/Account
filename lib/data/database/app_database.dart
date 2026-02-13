import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/transactions.dart';
import 'tables/categories.dart';
import 'tables/budgets.dart';
import 'tables/sync_logs.dart';

part 'app_database.g.dart';

/// 萌宠账本数据库
@DriftDatabase(tables: [Transactions, Categories, Budgets, SyncLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  // 后台任务专用构造函数
  AppDatabase.connect(super.executor);

  @override
  int get schemaVersion => 1;

  // ============ 账单操作 ============

  /// 插入账单
  Future<int> insertTransaction(TransactionsCompanion entry) {
    return into(transactions).insert(entry);
  }

  /// 获取所有账单（按时间倒序）
  Future<List<Transaction>> getAllTransactions() {
    return (select(transactions)..orderBy([(t) => OrderingTerm.desc(t.datetime)])).get();
  }

  /// 获取指定日期范围的账单
  Future<List<Transaction>> getTransactionsByDateRange(DateTime start, DateTime end) {
    return (select(transactions)
          ..where((t) => t.datetime.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.desc(t.datetime)]))
        .get();
  }

  /// 获取今日账单
  Future<List<Transaction>> getTodayTransactions() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getTransactionsByDateRange(startOfDay, endOfDay);
  }

  /// 获取本月账单
  Future<List<Transaction>> getCurrentMonthTransactions() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);
    return getTransactionsByDateRange(startOfMonth, endOfMonth);
  }

  /// 获取今日支出总额
  Future<double> getTodayExpenseTotal() async {
    final todayTransactions = await getTodayTransactions();
    double total = 0.0;
    for (final t in todayTransactions) {
      if (t.isExpense) total += t.amount;
    }
    return total;
  }

  /// 获取本月支出总额
  Future<double> getCurrentMonthExpenseTotal() async {
    final monthTransactions = await getCurrentMonthTransactions();
    double total = 0.0;
    for (final t in monthTransactions) {
      if (t.isExpense) total += t.amount;
    }
    return total;
  }

  /// 获取最近一条账单
  Future<Transaction?> getLatestTransaction() {
    return (select(transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 删除账单
  Future<int> deleteTransaction(int id) {
    return (delete(transactions)..where((t) => t.id.equals(id))).go();
  }

  /// 更新账单
  Future<bool> updateTransaction(Transaction entry) {
    return update(transactions).replace(entry);
  }

  // ============ 分类操作 ============

  /// 获取或创建分类
  Future<Category> getOrCreateCategory(String name, String type, bool isExpense) async {
    final existing = await (select(categories)
          ..where((c) => c.name.equals(name)))
        .getSingleOrNull();

    if (existing != null) {
      // 增加使用次数
      await (update(categories)..where((c) => c.id.equals(existing.id))).write(
        CategoriesCompanion(usageCount: Value(existing.usageCount + 1)),
      );
      return existing;
    }

    // 创建新分类
    final id = await into(categories).insert(CategoriesCompanion(
      name: Value(name),
      type: Value(type),
      isExpense: Value(isExpense),
      usageCount: const Value(1),
    ));

    return (select(categories)..where((c) => c.id.equals(id))).getSingle();
  }

  /// 获取热门分类
  Future<List<Category>> getTopCategories({int limit = 10, bool? isExpense}) {
    var query = select(categories);
    if (isExpense != null) {
      query = query..where((c) => c.isExpense.equals(isExpense));
    }
    return (query
          ..orderBy([(c) => OrderingTerm.desc(c.usageCount)])
          ..limit(limit))
        .get();
  }

  /// 获取所有分类
  Future<List<Category>> getAllCategories() {
    return select(categories).get();
  }

  // ============ 预算操作 ============

  /// 获取指定月份预算
  Future<Budget?> getBudget(int year, int month) {
    return (select(budgets)
          ..where((b) => b.year.equals(year) & b.month.equals(month)))
        .getSingleOrNull();
  }

  /// 获取当前月份预算
  Future<Budget?> getCurrentMonthBudget() {
    final now = DateTime.now();
    return getBudget(now.year, now.month);
  }

  /// 设置预算
  Future<int> setBudget(int year, int month, double amount) async {
    final existing = await getBudget(year, month);
    if (existing != null) {
      await (update(budgets)..where((b) => b.id.equals(existing.id))).write(
        BudgetsCompanion(
          amount: Value(amount),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return existing.id;
    }
    return into(budgets).insert(BudgetsCompanion(
      year: Value(year),
      month: Value(month),
      amount: Value(amount),
    ));
  }

  // ============ 同步日志操作 ============

  /// 记录同步日志
  Future<int> logSync({
    required bool success,
    String? errorMsg,
    String syncType = 'upload',
  }) {
    return into(syncLogs).insert(SyncLogsCompanion(
      syncTime: Value(DateTime.now()),
      success: Value(success),
      errorMsg: Value(errorMsg),
      syncType: Value(syncType),
    ));
  }

  /// 获取最近同步日志
  Future<SyncLog?> getLatestSyncLog() {
    return (select(syncLogs)
          ..orderBy([(s) => OrderingTerm.desc(s.syncTime)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// 清空所有数据
  Future<void> clearAllData() async {
    await delete(transactions).go();
    await delete(categories).go();
    await delete(budgets).go();
    await delete(syncLogs).go();
  }

  // ============ 统计查询 ============

  /// 按大类统计支出
  Future<Map<String, double>> getExpenseByType({DateTime? start, DateTime? end}) async {
    var query = select(transactions)..where((t) => t.isExpense.equals(true));
    
    if (start != null && end != null) {
      query = query..where((t) => t.datetime.isBetweenValues(start, end));
    }
    
    final results = await query.get();
    final Map<String, double> typeSum = {};
    
    for (final t in results) {
      typeSum[t.categoryType] = (typeSum[t.categoryType] ?? 0) + t.amount;
    }
    
    return typeSum;
  }

  /// 获取本月按大类统计
  Future<Map<String, double>> getCurrentMonthExpenseByType() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);
    return getExpenseByType(start: startOfMonth, end: endOfMonth);
  }

  // ============ 导出/导入 ============

  /// 导出所有数据为 Map
  Future<Map<String, dynamic>> exportAllData() async {
    final allTransactions = await getAllTransactions();
    final allCategories = await getAllCategories();
    final allBudgets = await select(budgets).get();

    return {
      'version': 1,
      'exportTime': DateTime.now().toIso8601String(),
      'transactions': allTransactions.map((t) => {
        'id': t.id,
        'amount': t.amount,
        'isExpense': t.isExpense,
        'category': t.category,
        'categoryType': t.categoryType,
        'note': t.note,
        'emoji': t.emoji,
        'datetime': t.datetime.toIso8601String(),
        'createdAt': t.createdAt.toIso8601String(),
      }).toList(),
      'categories': allCategories.map((c) => {
        'id': c.id,
        'name': c.name,
        'type': c.type,
        'isExpense': c.isExpense,
        'usageCount': c.usageCount,
      }).toList(),
      'budgets': allBudgets.map((b) => {
        'id': b.id,
        'year': b.year,
        'month': b.month,
        'amount': b.amount,
      }).toList(),
    };
  }

  /// 从 Map 导入数据并覆盖现有数据
  Future<void> importAllData(Map<String, dynamic> data) async {
    await transaction(() async {
      // 1. 清空旧数据
      await clearAllData();

      // 2. 导入分类
      if (data['categories'] != null) {
        final categoriesData = data['categories'] as List;
        await batch((b) {
          b.insertAll(categories, categoriesData.map((c) => CategoriesCompanion.insert(
            id: Value(c['id']),
            name: c['name'],
            type: c['type'],
            isExpense: Value(c['isExpense'] ?? true),
            usageCount: Value(c['usageCount'] ?? 0),
            createdAt: Value(c['createdAt'] != null ? DateTime.parse(c['createdAt']) : DateTime.now()),
          )));
        });
      }

      // 3. 导入账单
      if (data['transactions'] != null) {
        final transactionsData = data['transactions'] as List;
        await batch((b) {
          b.insertAll(transactions, transactionsData.map((t) => TransactionsCompanion.insert(
            id: Value(t['id']),
            amount: ConvertToDouble(t['amount']),
            isExpense: Value(t['isExpense'] ?? true),
            category: t['category'],
            categoryType: t['categoryType'],
            note: Value(t['note']),
            emoji: Value(t['emoji']),
            datetime: DateTime.parse(t['datetime']),
            createdAt: Value(t['createdAt'] != null ? DateTime.parse(t['createdAt']) : DateTime.now()),
          )));
        });
      }

      // 4. 导入预算
      if (data['budgets'] != null) {
        final budgetsData = data['budgets'] as List;
        await batch((b) {
          b.insertAll(budgets, budgetsData.map((bu) => BudgetsCompanion.insert(
            id: Value(bu['id']),
            year: bu['year'],
            month: bu['month'],
            amount: ConvertToDouble(bu['amount']),
            createdAt: Value(bu['createdAt'] != null ? DateTime.parse(bu['createdAt']) : DateTime.now()),
            updatedAt: Value(bu['updatedAt'] != null ? DateTime.parse(bu['updatedAt']) : DateTime.now()),
          )));
        });
      }
    });
  }

  double ConvertToDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0.0;
  }
}

/// 打开数据库连接
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pet_ledger.db'));
    return NativeDatabase.createInBackground(file);
  });
}
