import 'package:drift/drift.dart';

/// 账单记录表
class Transactions extends Table {
  /// 主键
  IntColumn get id => integer().autoIncrement()();
  
  /// 金额
  RealColumn get amount => real()();
  
  /// 是否为支出 (true=支出, false=收入)
  BoolColumn get isExpense => boolean().withDefault(const Constant(true))();
  
  /// 细分类别 (LLM返回，如"奶茶")
  TextColumn get category => text()();
  
  /// 大类 (如"餐饮"、"交通")
  TextColumn get categoryType => text()();
  
  /// 备注/事件描述
  TextColumn get note => text().nullable()();
  
  /// 情绪词检测后的表情
  TextColumn get emoji => text().nullable()();
  
  /// 消费时间
  DateTimeColumn get datetime => dateTime()();
  
  /// 记录创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
