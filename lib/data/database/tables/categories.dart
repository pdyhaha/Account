import 'package:drift/drift.dart';

/// 分类表 - 动态积累 LLM 返回的分类
class Categories extends Table {
  /// 主键
  IntColumn get id => integer().autoIncrement()();
  
  /// 分类名 (如"奶茶"、"剧本杀")
  TextColumn get name => text().unique()();
  
  /// 所属大类 (如"餐饮"、"娱乐")
  TextColumn get type => text()();
  
  /// 是否为支出分类
  BoolColumn get isExpense => boolean().withDefault(const Constant(true))();
  
  /// 使用次数，用于统计热门分类
  IntColumn get usageCount => integer().withDefault(const Constant(0))();
  
  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
