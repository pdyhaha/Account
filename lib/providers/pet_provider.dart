import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/pet_prompts.dart';
import 'budget_provider.dart';
import '../services/widget_service.dart';

/// 宠物类型
class PetType {
  final String name;
  final String label;
  final String assetPath; // 兼容旧名称，实际可能是文件路径
  final String description;
  final bool isCustom;

  const PetType({
    required this.name,
    required this.label,
    required this.assetPath,
    required this.description,
    this.isCustom = false,
  });

  // ============ 预设宠物 ============
  static const bee = PetType(name: 'bee', label: '蜜蜂', assetPath: 'assets/pets/bee.png', description: '勤劳、嗡嗡嗡、甜美');
  static const bunny = PetType(name: 'bunny', label: '兔子', assetPath: 'assets/pets/bunny.png', description: '软萌、活泼、爱吃胡萝卜');
  static const cat = PetType(name: 'cat', label: '猫咪', assetPath: 'assets/pets/cat.png', description: '傲娇、慵懒、偶尔撒娇');
  static const chameleon = PetType(name: 'chameleon', label: '变色龙', assetPath: 'assets/pets/chameleon.png', description: '隐身高手、色彩大师、佛系');
  static const crocodile = PetType(name: 'crocodile', label: '鳄鱼', assetPath: 'assets/pets/crocodile.png', description: '看起来凶凶的、其实很温柔');
  static const dog = PetType(name: 'dog', label: '狗狗', assetPath: 'assets/pets/dog.png', description: '热情、忠诚、最好的朋友');
  static const elephant = PetType(name: 'elephant', label: '大象', assetPath: 'assets/pets/elephant.png', description: '稳重、聪明、记忆力好');
  static const fox = PetType(name: 'fox', label: '狐狸', assetPath: 'assets/pets/fox.png', description: '机灵、狡黠、优雅');
  static const frog = PetType(name: 'frog', label: '青蛙', assetPath: 'assets/pets/frog.png', description: '呱呱呱、跳得高、大眼睛');
  static const hedgehog = PetType(name: 'hedgehog', label: '刺猬', assetPath: 'assets/pets/hedgehog.png', description: '社恐、带刺、害羞');
  static const hippopotamus = PetType(name: 'hippopotamus', label: '河马', assetPath: 'assets/pets/hippopotamus.png', description: '圆滚滚、水、憨厚');
  static const koala = PetType(name: 'koala', label: '考拉', assetPath: 'assets/pets/koala.png', description: '慢吞吞、贪睡、温和');
  static const penguin = PetType(name: 'penguin', label: '企鹅', assetPath: 'assets/pets/penguin.png', description: '呆萌、摇摇摆摆、绅士');
  static const pig = PetType(name: 'pig', label: '小猪', assetPath: 'assets/pets/pig.png', description: '乐天派、贪吃、憨厚');
  static const squirrel = PetType(name: 'squirrel', label: '松鼠', assetPath: 'assets/pets/squirrel.png', description: '机灵、囤积狂、毛茸茸');
  static const tiger = PetType(name: 'tiger', label: '老虎', assetPath: 'assets/pets/tiger.png', description: '威猛、霸气、森林之王');
  static const dragon = PetType(name: 'dragon', label: '恐龙', assetPath: 'assets/pets/dragon.png', description: '古老、强大、神秘');

  static List<PetType> get presets => [
    bee, bunny, cat, chameleon, crocodile, dog, elephant, fox, 
    frog, hedgehog, hippopotamus, koala, penguin, pig, squirrel, tiger, dragon
  ];

  static List<PetType> get values => presets; // 兼容旧代码

  Map<String, dynamic> toJson() => {
    'name': name,
    'label': label,
    'assetPath': assetPath,
    'description': description,
    'isCustom': isCustom,
  };

  factory PetType.fromJson(Map<String, dynamic> json) => PetType(
    name: json['name'],
    label: json['label'],
    assetPath: json['assetPath'],
    description: json['description'],
    isCustom: json['isCustom'] ?? false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetType &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  /// 获取对应的预设代用品 (用于小组件显示)
  PetType get fallbackPreset {
    if (!isCustom) return this;
    final index = name.hashCode.abs() % presets.length;
    return presets[index];
  }
}

/// 宠物心情枚举
enum PetMood { happy, normal, worry, sad }

/// 宠物状态
class PetState {
  final PetType type;
  final PetMood mood;
  final String message;
  final String animationName;

  const PetState({
    required this.type,
    required this.mood,
    required this.message,
    required this.animationName,
    this.allPets = const [],
  });

  final List<PetType> allPets;

  PetState copyWith({
    PetType? type,
    PetMood? mood,
    String? message,
    String? animationName,
    List<PetType>? allPets,
  }) {
    return PetState(
      type: type ?? this.type,
      mood: mood ?? this.mood,
      message: message ?? this.message,
      animationName: animationName ?? this.animationName,
      allPets: allPets ?? this.allPets,
    );
  }
}

/// 宠物状态 Notifier
class PetNotifier extends StateNotifier<PetState> {
  final Ref _ref;
  static final _random = Random();

  PetNotifier(this._ref)
      : super(PetState(
          type: PetType.chameleon, // 默认初始值，后面 load 会覆盖
          mood: PetMood.normal,
          message: PetPrompts.randomGreeting,
          animationName: 'idle',
          allPets: [...PetType.presets],
        )) {
    _init();
  }

  Future<void> _init() async {
    await _loadFromPrefs();
    
    // 监听预算比例，实时调整宠物状态和文案
    _ref.listen<AsyncValue<double>>(budgetRatioProvider, (prev, next) {
      next.whenData((ratio) {
         _updateStateFromRatio(ratio);
      });
    }, fireImmediately: true);
  }

  static const _prefKeyCustomPets = 'custom_pets';
  static const _prefKeySelectedPet = 'selected_pet_name';

  List<PetType> get _customPets => state.allPets.where((p) => p.isCustom).toList();
  List<PetType> get allPets => state.allPets;

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 加载自定义宠物
    final customJson = prefs.getString(_prefKeyCustomPets);
    if (customJson != null) {
      try {
        final List decode = jsonDecode(customJson);
        final customPets = decode.map((e) => PetType.fromJson(e)).toList();
        state = state.copyWith(allPets: [...PetType.presets, ...customPets]);
      } catch (e) {
        print('Load custom pets failed: $e');
      }
    }

    // 加载当前选中的宠物
    final selectedName = prefs.getString(_prefKeySelectedPet);
    if (selectedName != null) {
      final found = allPets.firstWhere((p) => p.name == selectedName, orElse: () => PetType.chameleon);
      state = state.copyWith(type: found);
    } else {
      // 第一次进入，随机一个预设宠物
      state = state.copyWith(type: _randomPetType());
      _saveSelectedPet();
    }
  }

  Future<void> _saveSelectedPet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeySelectedPet, state.type.name);
  }

  Future<void> _saveCustomPets() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_customPets.map((e) => e.toJson()).toList());
    await prefs.setString(_prefKeyCustomPets, json);
  }

  /// 添加自定义宠物
  Future<void> addCustomPet(PetType pet) async {
    state = state.copyWith(allPets: [...state.allPets, pet]);
    await _saveCustomPets();
    // 切换到新添加的宠物
    switchPetType(pet);
  }

  /// 删除自定义宠物
  Future<void> removeCustomPet(String name) async {
    final newList = state.allPets.where((p) => p.name != name).toList();
    state = state.copyWith(allPets: newList);
    await _saveCustomPets();
    
    // 如果删除的是当前选中的，切换到一个预设的
    if (state.type.name == name) {
      final presets = PetType.presets;
      switchPetType(presets[0]);
    }
    
    // 强制同步一次小组件，确保删除后画面更新
    _syncToWidget();
  }

  /// 随机选择宠物类型
  static PetType _randomPetType() {
    final types = PetType.values;
    return types[_random.nextInt(types.length)];
  }

  /// 根据比例更新宠物状态
  void _updateStateFromRatio(double ratio) {
    // 如果正在进行特定互动，不立即覆盖文案
    if (state.animationName == 'asking' || state.animationName == 'success') {
      return;
    }

    final mood = _getMoodFromRatio(ratio);
    final message = PetPrompts.getPromptByBudgetRatio(ratio);
    
    state = state.copyWith(
      mood: mood,
      message: message,
      animationName: _getAnimationName(mood),
    );
    
    // 这里的同步可以根据需要决定是否每次都触发，或者在 refresh 中触发
    _syncToWidget();
  }

  /// 根据预算更新心情 (保留异步接口兼容性)
  Future<void> _updateMoodFromBudget() async {
    try {
      final ratio = await _ref.read(budgetRatioProvider.future);
      _updateStateFromRatio(ratio);
    } catch (_) {
      // 预算未设置，保持默认状态
    }
  }

  /// 根据比例获取心情
  PetMood _getMoodFromRatio(double ratio) {
    if (ratio > 0.8) return PetMood.happy;
    if (ratio > 0.5) return PetMood.normal;
    if (ratio > 0.2) return PetMood.worry;
    return PetMood.sad;
  }

  /// 根据心情获取动画名
  String _getAnimationName(PetMood mood) {
    switch (mood) {
      case PetMood.happy:
        return 'happy';
      case PetMood.normal:
        return 'idle';
      case PetMood.worry:
        return 'worry';
      case PetMood.sad:
        return 'sad';
    }
  }

  /// 点击互动
  void onTap() {
    state = state.copyWith(
      message: PetPrompts.randomGreeting,
      animationName: 'tap',
    );
    
    // 2秒后恢复到根据预算决定的状态
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _updateMoodFromBudget();
      }
    });
  }

  /// 记账成功反馈
  void onTransactionSuccess() {
    state = state.copyWith(
      message: PetPrompts.randomSuccess,
      animationName: 'success',
    );
    
    // 2秒后恢复到根据预算决定的状态
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _updateMoodFromBudget();
      }
    });
  }

  /// 切换宠物类型
  void switchPetType(PetType type) {
    state = state.copyWith(type: type);
    _saveSelectedPet();
    _syncToWidget();
  }

  /// 随机切换宠物
  void randomizePet() {
    state = state.copyWith(type: _randomPetType());
    _saveSelectedPet();
    _syncToWidget();
  }

  /// 同步到小组件
  void _syncToWidget() {
    // 使用 microtask 避免 UI 渲染循环冲突，并传入当前 state 避免 circular dependency
    final currentState = state;
    Future.microtask(() {
      // 对于自定义宠物，assetPath 就是实际图片路径
      final customPath = currentState.type.isCustom ? currentState.type.assetPath : null;
      WidgetService.forceUpdateWidget(_ref, petState: currentState, customImagePath: customPath);
    });
  }

  /// 设置追问状态
  void setAskingState(String message) {
    state = state.copyWith(
      message: message,
      animationName: 'asking',
    );
  }

  /// 刷新
  Future<void> refresh() async {
    await _updateMoodFromBudget();
  }
}

/// 宠物状态 Provider
final petProvider = StateNotifierProvider<PetNotifier, PetState>((ref) {
  return PetNotifier(ref);
});

/// 当前宠物 Lottie 文件路径 Provider (已移除 Lottie 支持，统一使用静态图片)
final petLottiePathProvider = Provider<String?>((ref) {
  return null;
});
