import 'package:drift/drift.dart';

/// 预算表
class Budgets extends Table {
  /// 主键
  IntColumn get id => integer().autoIncrement()();
  
  /// 年份
  IntColumn get year => integer()();
  
  /// 月份 (1-12)
  IntColumn get month => integer()();
  
  /// 预算金额
  RealColumn get amount => real()();
  
  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  /// 更新时间
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {year, month},
  ];
}
