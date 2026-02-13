import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart';
import '../core/config/app_config.dart';
import 'package:flutter/foundation.dart';

/// LLM 解析结果
class LLMResult {
  final bool valid;
  final double? amount;
  final String? category;
  final String? type;
  final String? event;
  final bool isExpense;
  final String? datetime;
  final List<String> missingFields;
  final String? promptText; // 新增字段
  final String? rawResponse;

  LLMResult({
    required this.valid,
    this.amount,
    this.category,
    this.type,
    this.event,
    this.isExpense = true,
    this.datetime,
    this.missingFields = const [],
    this.promptText,
    this.rawResponse,
  });

  factory LLMResult.fromJson(Map<String, dynamic> json) {
    // 兼容旧格式
    List<String> missing = [];
    if (json['missing_fields'] is List) {
      missing = List<String>.from(json['missing_fields']);
    } else if (json['missing_field'] is String) {
      missing = [json['missing_field']];
    }

    return LLMResult(
      valid: json['valid'] ?? false,
      amount: json['amount']?.toDouble(),
      category: json['category'],
      type: json['type'],
      event: json['event'],
      isExpense: json['is_expense'] ?? true,
      datetime: json['datetime'],
      missingFields: missing,
      promptText: json['prompt_text'],
    );
  }

  factory LLMResult.invalid({String? rawResponse}) {
    return LLMResult(
      valid: false,
      rawResponse: rawResponse,
    );
  }

  /// 是否信息完整
  bool get isComplete => valid && missingFields.isEmpty && amount != null && event != null && datetime != null;

  /// 缺失金额
  bool get isMissingAmount => missingFields.contains('amount');

  /// 缺失事件
  bool get isMissingEvent => missingFields.contains('event');

  /// 缺失时间
  bool get isMissingTime => missingFields.contains('time');

  @override
  String toString() {
    return 'LLMResult(valid: $valid, amount: $amount, missingFields: $missingFields, promptText: $promptText)';
  }
}

/// DeepSeek LLM 服务
class LLMService {
  static final LLMService _instance = LLMService._internal();
  factory LLMService() => _instance;
  LLMService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));
  
  // 默认使用 AppConfig 中的配置
  String? _apiKey = AppConfig.llmApiKey;
  String _baseUrl = AppConfig.llmBaseUrl;
  String _model = AppConfig.llmModel;

  /// 配置 API
  void configure({
    required String apiKey,
    String? baseUrl,
    String? model,
  }) {
    _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
    if (model != null) _model = model;
  }

  /// System Prompt
  static const String _systemPrompt = '''
你是「萌宠账本」的记账助手，负责从用户模糊、口语化的语音中精准提取记账信息。

## 核心任务
将用户的零散话语转化为结构化的 JSON 账单 data，并具备极强的纠错和补全能力。

## 输出格式
仅返回 JSON，不要任何回复语。

## 字段规范
- valid: bool，只要包含任何财务意图（买、花、赚、收、转）或具体物品金额，即为 true。
- amount: float|null，金额。需识别复合单位（如“五块五”->5.5，“一百五”->150，“快两百”->200）。若完全没提金额，返回 null。
- category: string|null，具体物品或服务（如“美式咖啡”、“滴滴打车”）。
- type: string|null，只能从 [餐饮, 交通, 购物, 娱乐, 生活, 医疗, 美妆护肤, 人情社交, 旅行, 收入, 其他] 中选择。
- event: string|null，对语义的完整还原（如输入“奶茶15”，event为“购买奶茶”）。
- is_expense: bool，true=支出（默认），false=收入。
- datetime: string|null，格式 yyyy-MM-dd HH:mm:ss。若未提时间请参考“时间补全规则”。
- missing_fields: ["amount", "time", "event"] 字符串数组，列出确缺失的字段。
- prompt_text: string|null，当有缺失字段时，扮演动物进行追问（语气由角色设定决定）。

## 模糊/不完整语音处理策略
1. **语义纠错**：
   - 识别同音字或录音识别错误（如“五快”->“五块”，“和牛奶”->“喝牛奶”）。
   - 用户说“一百五”指 150，“一五”指 15 或 1.5。在这种情况下根据物品常识判断（奶茶一五通常是 15，打车一五可能是 15 或 1.5 公里，需取 15 元）。
2. **逻辑推断**：
   - “吃了顿火锅” -> 提示缺失金额和时间，而不是直接标记无效。
   - “昨天奶茶15” -> 时间推算为昨天的 12:00:00。
3. **极简解析**：
   - 即使只有“奶茶15”，也要识别出 amount=15, category="奶茶", type="餐饮"。

## 时间补全规则
- **参考坐标系**：User Prompt 中的“当前时间”用于推回相对时刻。
- **默认策略**：
  - 用户未提时间：datetime 设为 null，缺失字段加 "time"。
  - 提到“刚才/现在”：使用当前精确时间。
  - 只有日期（昨天/周五）：设为该日 12:00:00。
  - 用餐关键词：
    - 早餐 -> 08:30:00
    - 午餐 -> 12:30:00
    - 晚餐 -> 19:00:00
    - 夜宵 -> 22:30:00

## 收入逻辑
- 包含：工资、发钱、到账、红包、中奖、报销、收钱。
- is_expense = false，type 设为“收入”。

## 示例
输入: "刚才在全家买了个关东煮，二十五块六"
输出: {"valid":true,"amount":25.6,"category":"关东煮","type":"餐饮","event":"全家买关东煮","is_expense":true,"datetime":"now","missing_fields":[],"prompt_text":null}

输入: "去买奶茶" (完全没提钱)
输出: {"valid":true,"amount":null,"category":"奶茶","type":"餐饮","event":"购买奶茶","is_expense":true,"datetime":null,"missing_fields":["amount","time"],"prompt_text":"呜喵~买奶茶花了多少钱呀？是刚刚买的吗？"}

输入: "一百五" (没提做什么)
输出: {"valid":true,"amount":150.0,"category":null,"type":null,"event":null,"is_expense":true,"datetime":null,"missing_fields":["event","time"],"prompt_text":"汪！这一百五十块是花在哪里了呀？是什么时候的事情？"}
''';

  /// 获取丰富的时间上下文
  String _getRichTimeContext() {
    final now = DateTime.now();
    final solar = Solar.fromDate(now);
    final lunar = Lunar.fromDate(now);
    
    final weekDay = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][now.weekday - 1];
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    
    final sb = StringBuffer();
    sb.writeln('当前时间: $timeStr $weekDay');
    sb.writeln('农历: ${lunar.getYearInGanZhi()}年(${lunar.getYearShengXiao()}) ${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}');
    
    // 节气
    final jieQi = lunar.getJieQi();
    if (jieQi.isNotEmpty) {
      sb.writeln('今日节气: $jieQi');
    } else {
      final nextJieQi = lunar.getNextJieQi();
      if (nextJieQi != null) {
        sb.writeln('下一个节气: ${nextJieQi.getName()} (${nextJieQi.getSolar().toYmd()})');
      }
    }
    
    // 节日
    final festivals = <String>[];
    festivals.addAll(lunar.getFestivals());
    festivals.addAll(solar.getFestivals());
    if (festivals.isNotEmpty) {
      sb.writeln('今日节日: ${festivals.join(", ")}');
    }
    
    // 距离春节倒计时
    Lunar nextSpring;
    var springThisYear = Lunar.fromYmd(lunar.getYear(), 1, 1);
    var springNextYear = Lunar.fromYmd(lunar.getYear() + 1, 1, 1);
    
    if (solar.isBefore(springThisYear.getSolar())) {
      nextSpring = springThisYear;
    } else {
      nextSpring = springNextYear;
    }
    
    if (lunar.getMonth() == 1 && lunar.getDay() == 1) {
       sb.writeln('提示: 今天就是春节！过年好！');
    } else {
       final days = nextSpring.getSolar().subtract(solar);
       sb.writeln('距离春节: 还有 $days 天 (${nextSpring.getSolar().toYmd()})');
    }
    
    return sb.toString();
  }

  /// 自由对话（用于日报生成等）
  Future<String?> chat(String prompt, {String? petType, String? petStyle}) async {
    final apiKey = AppConfig.llmApiKey;
    final baseUrl = AppConfig.llmBaseUrl;
    final model = AppConfig.llmModel;

    if (apiKey.isEmpty) return '请在 AppConfig 中设置有效的 LLM API Key';

    final timeContext = _getRichTimeContext();
    
    String systemContent = timeContext;
    if (petType != null) {
      final roleDesc = petStyle != null ? '$petType（$petStyle）' : petType;
      systemContent += '\n请扮演一只$roleDesc，用该动物特有的语气词开头，用简短、可爱的语气回答。';
    }

    try {
      final response = await _dio.post(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemContent},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': 500,
        },
      );

      final content = response.data['choices'][0]['message']['content'] as String;
      return content.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
    } on DioException catch (e) {
      debugPrint('LLM Chat DioError: ${e.type} - ${e.message} - Response: ${e.response?.data}');
      return null; // 回退到 Chat 页面的默认提示
    } catch (e) {
      debugPrint('LLM Chat Error: $e');
      return null;
    }
  }

  /// 解析用户输入
  Future<LLMResult> parse(String text, {String? petType, String? petStyle}) async {
    final apiKey = AppConfig.llmApiKey;
    final baseUrl = AppConfig.llmBaseUrl;
    final model = AppConfig.llmModel;

    if (apiKey.isEmpty) {
      return _localParse(text);
    }

    // 获取丰富的时间上下文
    final timeContext = _getRichTimeContext();
    
    // 注入动物角色和性格
    String stylePrompt = '';
    if (petType != null) {
      String toneWord = _getToneWordByAnimal(petType);
      String rolePlay = petStyle != null ? '一只$petType（性格：$petStyle）' : '一只$petType';
      
      stylePrompt = '''

## 角色扮演要求
你现在扮演$rolePlay。

## 语气规则
- 必须使用"$toneWord"作为语气词开头追问，例如："$toneWord？花了多少钱呀？"、"$toneWord？什么时候买的呢？"
- 追问话术必须符合该动物的性格特点
- 保持简短、可爱、口语化
'''; 
    }

    try {
      final response = await _dio.post(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': model,
          'messages': [
            {'role': 'system', 'content': _systemPrompt + stylePrompt},
            {'role': 'user', 'content': '$timeContext\n输入: "$text"'},
          ],
          'temperature': 0.1,
          'max_tokens': 500,
        },
      );

      final content = response.data['choices'][0]['message']['content'] as String;
      
      // 过滤深度思考标签
      final cleanContent = content.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
      
      // 提取 JSON
      final jsonStr = _extractJson(cleanContent);
      if (jsonStr == null) {
        return LLMResult.invalid(rawResponse: cleanContent);
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return LLMResult.fromJson(json);
    } on DioException catch (e) {
      debugPrint('LLM Parse DioError: ${e.message}');
      return _localParse(text);
    } catch (e) {
      return LLMResult.invalid(rawResponse: e.toString());
    }
  }

  /// 根据动物名称获取对应的语气词
  String _getToneWordByAnimal(String petType) {
    final toneMap = {
      '猫咪': '喵', '狗狗': '汪', '兔子': '嗯', '仓鼠': '吱', '熊猫': '嗯嗯',
      '考拉': '嗯', '狐狸': '哦', '小猪': '哼', '企鹅': '嘎', '小鸡': '叽',
      '鸭子': '嘎', '狮子': '吼', '老虎': '嗷', '独角兽': '哼~', '龙': '吼',
      '小熊猫': '嘤', '海獭': '呀', '卡皮巴拉': '嗯', '刺猬': '嘶', '羊驼': '嗯',
    };
    return toneMap[petType] ?? '喵';
  }

  /// 从响应中提取 JSON
  String? _extractJson(String content) {
    try {
      jsonDecode(content);
      return content;
    } catch (_) {}

    final jsonBlockRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final match = jsonBlockRegex.firstMatch(content);
    if (match != null) return match.group(1)?.trim();

    final braceRegex = RegExp(r'\{[\s\S]*\}');
    final braceMatch = braceRegex.firstMatch(content);
    if (braceMatch != null) return braceMatch.group(0);

    return null;
  }

  /// 本地简单解析（Fallback）
  LLMResult _localParse(String text) {
    if (text.trim().isEmpty) return LLMResult.invalid();

    double? amount;
    final amountPatterns = [
      RegExp(r'(\d+\.?\d*)\s*[块元]'),
      RegExp(r'[花了费]\s*(\d+\.?\d*)'),
      RegExp(r'(\d+\.?\d*)\s*[块钱]'),
    ];
    
    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        amount = double.tryParse(match.group(1) ?? '');
        if (amount != null) break;
      }
    }

    amount ??= _parseChineseNumber(text);

    final isExpense = !RegExp(r'(工资|发工资|到账|红包|收到|报销|收入|赚)').hasMatch(text);

    String? type;
    String? category;
    
    if (RegExp(r'(奶茶|咖啡|吃|餐|饭|外卖|零食)').hasMatch(text)) {
      type = '餐饮';
      category = _extractKeyword(text, ['奶茶', '咖啡', '外卖', '零食', '午餐', '晚餐', '早餐']);
    } else if (RegExp(r'(打车|滴滴|地铁|公交|加油)').hasMatch(text)) {
      type = '交通';
      category = _extractKeyword(text, ['打车', '滴滴', '地铁', '公交', '加油']);
    } else if (RegExp(r'(买|购物|淘宝|京东)').hasMatch(text)) {
      type = '购物';
    }

    List<String> missingFields = [];
    if (amount == null) missingFields.add('amount');
    if (type == null && category == null) missingFields.add('event');
    if (!RegExp(r'(昨天|今天|刚才|点|分)').hasMatch(text)) missingFields.add('time');

    return LLMResult(
      valid: true,
      amount: amount,
      category: category ?? type,
      type: type ?? '其他',
      event: text,
      isExpense: isExpense,
      missingFields: missingFields,
    );
  }

  String? _extractKeyword(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) return keyword;
    }
    return null;
  }

  double? _parseChineseNumber(String text) {
    final chineseNums = {
      '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
      '百': 100, '千': 1000, '万': 10000,
    };

    final pattern = RegExp(r'([零一二两三四五六七八九十百千万]+)[块元钱]');
    final match = pattern.firstMatch(text);
    if (match == null) return null;

    final chineseNum = match.group(1)!;
    double result = 0;
    double current = 0;

    for (int i = 0; i < chineseNum.length; i++) {
      final char = chineseNum[i];
      final value = chineseNums[char];
      if (value == null) continue;

      if (value >= 10) {
        if (current == 0) current = 1;
        current *= value;
        if (value == 10 && i == chineseNum.length - 1) {
          result += current;
          current = 0;
        }
      } else {
        if (i + 1 < chineseNum.length) {
          final nextValue = chineseNums[chineseNum[i + 1]];
          if (nextValue != null && nextValue >= 10) {
            current = value.toDouble();
          } else {
            result += current + value;
            current = 0;
          }
        } else {
          result += current + value;
          current = 0;
        }
      }
    }
    result += current;
    if (text.contains('块五') || text.contains('元五')) result += 0.5;
    return result > 0 ? result : null;
  }
}

final llmService = LLMService();
