import 'package:drift/drift.dart';

/// 同步记录表
class SyncLogs extends Table {
  /// 主键
  IntColumn get id => integer().autoIncrement()();
  
  /// 同步时间
  DateTimeColumn get syncTime => dateTime()();
  
  /// 是否成功
  BoolColumn get success => boolean()();
  
  /// 错误信息
  TextColumn get errorMsg => text().nullable()();
  
  /// 同步类型 (upload/download)
  TextColumn get syncType => text().withDefault(const Constant('upload'))();
}
