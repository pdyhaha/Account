/// 分类常量定义
/// 包含 10 个支出大类和 4 个收入分类
library;

class CategoryConstants {
  CategoryConstants._();

  // ============ 支出大类 ============
  
  static const List<CategoryType> expenseTypes = [
    CategoryType(
      name: '餐饮',
      emoji: '🍔',
      keywords: ['吃', '餐', '饭', '奶茶', '咖啡', '外卖', '火锅', '零食', '饮料', '甜品', '水果', '早餐', '午餐', '晚餐', '夜宵', '便利店', '全家', '711', '罗森', '面包', '蛋糕'],
    ),
    CategoryType(
      name: '交通',
      emoji: '🚗',
      keywords: ['打车', '滴滴', '出租', '地铁', '公交', '高铁', '火车', '机票', '加油', '停车', '过路费', '共享单车', '骑车'],
    ),
    CategoryType(
      name: '购物',
      emoji: '🛍️',
      keywords: ['买', '购', '淘宝', '京东', '拼多多', '衣服', '鞋子', '包', '数码', '电子', '日用品', '超市', '商场'],
    ),
    CategoryType(
      name: '娱乐',
      emoji: '🎮',
      keywords: ['电影', '游戏', 'KTV', '唱歌', '剧本杀', '密室', '演唱会', '音乐会', '展览', '游乐园', '玩', '会员', 'VIP', '视频'],
    ),
    CategoryType(
      name: '生活',
      emoji: '🏠',
      keywords: ['房租', '水电', '燃气', '话费', '网费', '物业', '快递', '维修', '家政', '理发', '洗衣'],
    ),
    CategoryType(
      name: '医疗',
      emoji: '💊',
      keywords: ['医院', '看病', '药', '体检', '挂号', '治疗', '手术', '保健'],
    ),
    CategoryType(
      name: '美妆护肤',
      emoji: '💄',
      keywords: ['化妆品', '护肤', '面膜', '口红', '粉底', '美甲', '美容', '美发', '香水', '精华', '防晒'],
    ),
    CategoryType(
      name: '人情社交',
      emoji: '🎁',
      keywords: ['红包', '送礼', '礼物', '请客', '份子钱', '聚餐', '聚会', '生日', '结婚', '随礼'],
    ),
    CategoryType(
      name: '旅行',
      emoji: '✈️',
      keywords: ['旅游', '酒店', '住宿', '门票', '景点', '民宿', '旅行', '度假', '出游'],
    ),
    CategoryType(
      name: '其他',
      emoji: '📝',
      keywords: [],
    ),
  ];

  // ============ 收入分类 ============
  
  static const List<CategoryType> incomeTypes = [
    CategoryType(
      name: '工资',
      emoji: '💰',
      keywords: ['工资', '发工资', '薪水', '到账', '发钱', '月薪', '奖金', '年终奖'],
    ),
    CategoryType(
      name: '红包',
      emoji: '🧧',
      keywords: ['红包', '收到红包', '微信红包', '支付宝红包', '压岁钱'],
    ),
    CategoryType(
      name: '报销',
      emoji: '📄',
      keywords: ['报销', '公司报销', '费用报销'],
    ),
    CategoryType(
      name: '其他',
      emoji: '💵',
      keywords: ['转账', '退款', '理财', '利息', '兼职', '副业'],
    ),
  ];

  /// 所有支出大类名称
  static List<String> get expenseTypeNames => 
      expenseTypes.map((e) => e.name).toList();
  
  /// 所有收入分类名称
  static List<String> get incomeTypeNames => 
      incomeTypes.map((e) => e.name).toList();

  /// 根据名称获取分类类型
  static CategoryType? getType(String name, {bool isExpense = true}) {
    final types = isExpense ? expenseTypes : incomeTypes;
    try {
      return types.firstWhere((t) => t.name == name);
    } catch (_) {
      return null;
    }
  }

  /// 根据名称获取 emoji
  static String getEmoji(String typeName) {
    final type = getType(typeName, isExpense: true) ?? 
                 getType(typeName, isExpense: false);
    return type?.emoji ?? '📝';
  }
}

/// 分类类型定义
class CategoryType {
  final String name;
  final String emoji;
  final List<String> keywords;

  const CategoryType({
    required this.name,
    required this.emoji,
    required this.keywords,
  });
}
