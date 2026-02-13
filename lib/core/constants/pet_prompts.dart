import 'dart:math';

/// 宠物台词库
/// 各种场景下的可爱文案

class PetPrompts {
  PetPrompts._();
  
  static final _random = Random();
  
  /// 随机获取一条文案
  static String _randomPick(List<String> prompts) {
    return prompts[_random.nextInt(prompts.length)];
  }

  // ============ 首页互动台词 ============
  
  static const List<String> greetingPrompts = [
    "今天要给我买罐罐吗？",
    "主人今天也要努力省钱哦~",
    "摸摸头就不记账了吗？",
    "有什么要记的吗？",
    "今天的口粮还够吃吗？",
    "记账使我快乐！（骗你的）",
    "主人主人，今天花钱了吗？",
    "我饿了... 是时候省钱了！",
  ];
  
  static String get randomGreeting => _randomPick(greetingPrompts);

  // ============ 记账成功台词 ============
  
  static const List<String> successPrompts = [
    "记好啦！你真棒~",
    "OK！账本已更新！",
    "收到！我会好好保管的~",
    "耶！又记了一笔！",
    "好的好的，记下来了！",
    "账本+1，继续加油！",
  ];
  
  static String get randomSuccess => _randomPick(successPrompts);

  // ============ 智能追问台词 ============
  
  /// 场景1：缺失金额
  static const List<String> missingAmountPrompts = [
    "收到！不过... 这笔'巨款'具体是多少呀？",
    "记下来啦，但是价格那一栏还空着呢~",
    "是 10 块还是 100 块？快告诉我，我要算账啦！",
    "记住了！但是... 花了多少钱呀？",
    "嗯嗯，然后呢？多少钱呀？",
  ];
  
  static String get randomMissingAmount => _randomPick(missingAmountPrompts);
  
  /// 场景2：缺失事件
  static const List<String> missingEventPrompts = [
    "钱已就位！是买了漂亮衣服还是好吃的？",
    "这笔钱花在哪里了呀？我的笔都急得没墨水啦！",
    "光记数字会忘掉的哦，给这笔账起个名字吧？",
    "收到金额！但是... 买了什么呀？",
    "这笔花销是用来做什么的呢？",
  ];
  
  static String get randomMissingEvent => _randomPick(missingEventPrompts);
  
  /// 场景3：缺失时间
  static const List<String> missingTimePrompts = [
    "记下来啦！这是什么时候花的呀？",
    "账本上时间那栏空着呢，是刚才还是之前呀？",
    "是今天花的吗？告诉我具体时间吧~",
    "什么时候的事呀？我要写上日期~",
  ];
  
  static String get randomMissingTime => _randomPick(missingTimePrompts);
  
  /// 场景4：无法解析/噪音
  static const List<String> invalidPrompts = [
    "信号被外星人劫持啦，没听清捏，再说一遍好不好？",
    "刚才风太大，我没听见，主人再说一次嘛~",
    "歪？歪？这里是萌宠台，请再讲一遍~",
    "咦？我没听懂... 可以再说一次吗？",
    "脑子有点转不过来，再说一遍呗~",
  ];
  
  static String get randomInvalid => _randomPick(invalidPrompts);

  // ============ 预算相关台词 ============
  
  /// 预算充足 (> 80%)
  static const List<String> budgetRichPrompts = [
    "富婆求包养！",
    "口粮充足，今天可以吃小鱼干~",
    "钱包鼓鼓的，开心！",
    "还有好多口粮，继续保持！",
  ];
  
  static String get randomBudgetRich => _randomPick(budgetRichPrompts);
  
  /// 预算正常 (50-80%)
  static const List<String> budgetNormalPrompts = [
    "口粮还够吃，但要省着点~",
    "不多不少，刚刚好！",
    "继续保持这个节奏~",
  ];
  
  static String get randomBudgetNormal => _randomPick(budgetNormalPrompts);
  
  /// 预算紧张 (20-50%)
  static const List<String> budgetTightPrompts = [
    "口粮快不够了，要省钱啦！",
    "今天开始吃土...",
    "剩得不多了，悠着点花~",
  ];
  
  static String get randomBudgetTight => _randomPick(budgetTightPrompts);
  
  /// 预算告急 (< 20%)
  static const List<String> budgetCriticalPrompts = [
    "由于没钱，小猫已离家出走（开玩笑的）",
    "本月口粮告急！求投喂！",
    "穷到只能舔爪子了...",
    "口粮见底了，下个月要加油！",
  ];
  
  static String get randomBudgetCritical => _randomPick(budgetCriticalPrompts);

  /// 根据预算剩余比例获取对应台词
  static String getPromptByBudgetRatio(double ratio) {
    if (ratio > 0.8) {
      return randomBudgetRich;
    } else if (ratio > 0.5) {
      return randomBudgetNormal;
    } else if (ratio > 0.1) {
      return randomBudgetTight;
    } else {
      return randomBudgetCritical;
    }
  }
}
