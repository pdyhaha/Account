import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:home_widget/home_widget.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/constants/pet_prompts.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/pet_provider.dart' show petProvider, PetType, PetMood;
import '../../providers/database_provider.dart';
import '../../services/widget_service.dart';
import '../../core/utils/pet_helper.dart';
import '../../services/speech_service.dart';
import '../../services/llm_service.dart';
import '../../services/sound_service.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/voice/sound_wave.dart';
import '../../widgets/voice/receipt_card.dart';

/// 语音记账状态
enum VoiceState {
  idle,       // 等待开始
  listening,  // 正在听
  processing, // 正在处理
  confirming, // 确认中
  asking,     // 追问中
  success,    // 成功
  error,      // 错误
}

/// 语音记账浮窗页面
class VoiceOverlayPage extends ConsumerStatefulWidget {
  final bool isStandalone;

  const VoiceOverlayPage({
    super.key,
    this.isStandalone = false,
  });

  @override
  ConsumerState<VoiceOverlayPage> createState() => _VoiceOverlayPageState();
}

class _VoiceOverlayPageState extends ConsumerState<VoiceOverlayPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  VoiceState _state = VoiceState.idle;
  String _recognizedText = '';
  String _petMessage = '点击麦克风开始说话~';
  LLMResult? _llmResult;
  
  // 追问上下文
  String? _pendingEvent;
  double? _pendingAmount;
  String? _lastRawText; // 上一次的原始识别文本
  Timer? _silenceTimer; // 静音检测定时器

  late AnimationController _petAnimController;
  late Animation<double> _petBounceAnimation;

  @override
  void initState() {
    super.initState();
    _petAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _petBounceAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _petAnimController, curve: Curves.elasticOut),
    );

    _setupSpeechService();
    
    // 从小组件同步宠物信息
    // _syncPetFromWidget(); // 已禁用：改由 PetNotifier 从本地配置直接加载，确保与主 App 一致
    
    WidgetsBinding.instance.addObserver(this);
    
    // 页面加载后自动开始录音
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoListening();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 当应用从后台回到前台（或重新显示）时，自动重置状态并开始录音
      _resetAndStartListening();
    }
  }

  Future<void> _resetAndStartListening() async {
    // 如果当前已经是成功或确认状态，不做处理，防止用户还未操作就被重置
    if (_state == VoiceState.confirming || _state == VoiceState.success) return;
    
    // 重置为初始状态
    setState(() {
      _state = VoiceState.idle;
      _recognizedText = '';
      _petMessage = '点击麦克风开始说话~';
      _llmResult = null;
      _pendingEvent = null;
      _pendingAmount = null;
      _lastRawText = null;
    });
    
    // 重新开始录音
    await _startAutoListening();
  }
  
  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      if (_state == VoiceState.listening && _recognizedText.isNotEmpty) {
        print('VoiceOverlay: 3s silence detected, auto-stopping...');
        speechService.stopListening();
      }
    });
  }

  void _stopSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }
  
  // _syncPetFromWidget 已移除：直接信赖 App 本地存储的设置
  
  /// 根据表情推断宠物类型
  PetType _getPetTypeFromEmoji(String emoji) {
    switch (emoji) {
      case '🐝': return PetType.bee;
      case '🐰':
      case '🐇': return PetType.bunny;
      case '😻':
      case '😺':
      case '🐱': return PetType.cat;
      case '🦎': return PetType.chameleon;
      case '🐊': return PetType.crocodile;
      case '🐶':
      case '🐕': return PetType.dog;
      case '🐘': return PetType.elephant;
      case '🦊': return PetType.fox;
      case '🐸': return PetType.frog;
      case '🦔': return PetType.hedgehog;
      case '🦛': return PetType.hippopotamus;
      case '🐨': return PetType.koala;
      case '🐧': return PetType.penguin;
      case '🐷': return PetType.pig;
      case '🐿️': return PetType.squirrel;
      case '🐯':
      case '🐅': return PetType.tiger;
      case '🐲':
      case '🦕': 
      case '🦖': return PetType.dragon;
      default: return PetType.chameleon;
    }
  }

  Future<void> _startAutoListening() async {
    // 稍微延迟一点，等待页面动画完成
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    
    // 检查权限
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      setState(() {
        _state = VoiceState.error;
        _petMessage = '请在设置中允许麦克风权限';
      });
      return;
    }

    if (_state == VoiceState.idle) {
      _toggleListening();
    }
  }

  void _setupSpeechService() {
    speechService.onResult = (text, isFinal) {
      if (!mounted) return;
      setState(() {
        _recognizedText = text;
      });
      
      // 只要有内容输入，就重置静音定时器
      if (text.isNotEmpty) {
        _resetSilenceTimer();
      }
      
      if (isFinal && text.isNotEmpty) {
        _stopSilenceTimer();
        _processText(text);
      }
    };

    speechService.onError = (error) {
      if (!mounted) return;
      setState(() {
        _state = VoiceState.error;
        _petMessage = error;
      });
    };

    speechService.onStatusChange = (isListening) {
      if (!mounted) return;
      
      if (isListening) {
        // 开始录音时启动定时器
        _resetSilenceTimer();
      } else {
        // 停止录音时取消定时器
        _stopSilenceTimer();
      }

      // 只有在真的停止并且没有识别结果时才重置状态
      if (!isListening && _state == VoiceState.listening && _recognizedText.isEmpty) {
        setState(() {
          _state = VoiceState.idle;
          _petMessage = '刚才没听清...';
        });
      }
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 只有在监听状态下才停止，避免重复调用导致 Native 崩溃
    if (_state == VoiceState.listening) {
      speechService.stopListening();
    }
    _stopSilenceTimer();
    _petAnimController.dispose();
    super.dispose();
  }

  bool _isClosing = false;

  Future<void> _close() async {
    if (_isClosing) return;
    
    // 标记为正在关闭，触发 UI 变为空白，防止 GLES 资源竞争
    if (mounted) {
      setState(() {
        _isClosing = true;
      });
    }

    // 停止录音即可，不要调用 dispose (防止销毁流时触发底层的 mutex crash)
    // 让 Activity 销毁过程自然回收资源
    await speechService.stopListening();
    
    // 如果是嵌入模式（非独立 Activity），直接 Pop 路由，不要杀进程
    if (!widget.isStandalone) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }
    
    // --- 以下是独立 Activity 模式的专用销毁逻辑 (VoiceActivity) ---

    // 给足缓冲时间让 Engine 停止渲染当前帧，避免 Surface 销毁时的 Crash
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      // 使用 MethodChannel 安全退出 Activity
      const channel = MethodChannel('com.petledger/voice_control');
      await channel.invokeMethod('closeActivity');
    } catch (e) {
      print('VoiceOverlay: Failed to call closeActivity via channel: $e');
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果正在关闭，返回空白，停止渲染任何纹理
    if (_isClosing) {
      return const SizedBox();
    }

    return WillPopScope(
      onWillPop: () async {
        await _close();
        return false; // _close 处理了退出逻辑
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: () {
            if (_state == VoiceState.idle || _state == VoiceState.error) {
              _close();
            }
          },
          child: Container(
            color: AppColors.overlay,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {}, // 阻止点击穿透
                child: Column(
                  children: [
                    // 关闭按钮
                    _buildCloseButton(),
                    
                    Expanded(
                      child: _state == VoiceState.confirming && _llmResult != null
                          ? _buildConfirmView()
                          : _buildMainView(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: IconButton(
          onPressed: _close,
          icon: const Icon(Icons.close, color: Colors.white70, size: 28),
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 宠物区域
        _buildPetArea(),
        
        const SizedBox(height: 20),
        
        // 识别文字
        if (_recognizedText.isNotEmpty) _buildRecognizedText(),
        
        const SizedBox(height: 30),
        
        // 声波动画
        if (_state == VoiceState.listening)
          SoundWaveAnimation(
            isActive: true,
            color: AppColors.sakura,
            height: 50,
            barCount: 7,
          ),
        
        // 处理中动画
        if (_state == VoiceState.processing)
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.sakura),
          ),
        
        const SizedBox(height: 30),
        
        // 麦克风按钮
        _buildMicButton(),
        
        const SizedBox(height: 20),
        
        // 提示文字
        _buildHintText(),
      ],
    );
  }

  Widget _buildPetArea() {
    final petState = ref.watch(petProvider);
    // 如果是自定义宠物，这里使用预设代用品
    final displayType = petState.type.fallbackPreset;
    
    return Column(
      children: [
        // 气泡文案
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            _petMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 宠物
        ScaleTransition(
          scale: _petBounceAnimation,
          child: Image.asset(
            _getPetImage(displayType),
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  String _getPetImage(PetType type) {
    // 获取当前宠物心情
    final petState = ref.read(petProvider);
    final mood = petState.mood;
    
    // 根据语音状态和宠物心情返回对应表情
    switch (_state) {
      case VoiceState.listening:
        // 聆听中 - 专注/开心的表情
        return _getPetImageByMood(type, PetMood.happy);
      case VoiceState.processing:
        // 处理中 - 思考表情
        // TODO: 如果有思考状态的图片，这里返回
        return type.assetPath;
      case VoiceState.asking:
        // 追问中 - 疑惑/担心的表情
        return _getPetImageByMood(type, PetMood.worry);
      case VoiceState.success:
        // 成功 - 开心表情
        return _getPetImageByMood(type, PetMood.happy);
      default:
        // 默认状态 - 根据实际心情显示
        return _getPetImageByMood(type, mood);
    }
  }
  
  /// 根据宠物类型和心情获取图片路径
  String _getPetImageByMood(PetType type, PetMood mood) {
    // 暂时统一使用静态图片，不同心情的图片路径可以在此扩展
    return type.assetPath;
  }

  Widget _buildRecognizedText() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _state == VoiceState.listening
              ? AppColors.sakura
              : AppColors.divider,
          width: 2,
        ),
      ),
      child: Text(
        _recognizedText,
        style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMicButton() {
    final isListening = _state == VoiceState.listening;
    final isProcessing = _state == VoiceState.processing;
    
    return GestureDetector(
      onTap: isProcessing ? null : _toggleListening,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: isListening ? AppColors.expense : AppColors.sakura,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: (isListening ? AppColors.expense : AppColors.sakura)
                  .withAlpha(100),
              blurRadius: isListening ? 30 : 20,
              spreadRadius: isListening ? 5 : 0,
            ),
          ],
        ),
        child: Icon(
          isListening ? Icons.stop : Icons.mic,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildHintText() {
    String hint;
    switch (_state) {
      case VoiceState.idle:
        hint = '点击麦克风开始说话';
        break;
      case VoiceState.listening:
        hint = '正在聆听...';
        break;
      case VoiceState.processing:
        hint = '正在理解你说的话...';
        break;
      case VoiceState.asking:
        hint = '点击麦克风补充信息';
        break;
      default:
        hint = '';
    }
    
    return Text(
      hint,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
    );
  }

  Widget _buildConfirmView() {
    return Center(
      child: ReceiptCard(
        result: _llmResult!,
        onConfirm: _saveTransaction,
        onCancel: () {
          setState(() {
            _state = VoiceState.idle;
            _llmResult = null;
            _recognizedText = '';
            _petMessage = '取消了？再试一次吧~';
            _lastRawText = null;
            _pendingAmount = null;
            _pendingEvent = null;
          });
        },
        onEdit: (result) {
          setState(() {
            _llmResult = result;
          });
        },
      ),
    );
  }

  Future<void> _toggleListening() async {
    HapticFeedback.mediumImpact();
    
    if (_state == VoiceState.listening) {
      await speechService.stopListening();
      // onResult 回调会处理文本，这里只需要处理空文本的情况
      if (_recognizedText.isEmpty) {
        setState(() {
          _state = VoiceState.idle;
          _petMessage = '没听到呢，再说一次？';
        });
      }
    } else {
      setState(() {
        _state = VoiceState.listening;
        _recognizedText = '';
        _petMessage = '我在听呢~';
      });
      
      _petAnimController.forward().then((_) => _petAnimController.reverse());
      
      final success = await speechService.startListening();
      if (!success && mounted) {
        setState(() {
          _state = VoiceState.error;
          _petMessage = '无法启动语音识别，请检查麦克风权限和网络连接';
        });
      }
    }
  }

  Future<void> _processText(String text) async {
    if (!mounted) return;
    
    setState(() {
      _state = VoiceState.processing;
      _petMessage = '让我想想...';
    });
    
    // 构建完整上下文
    String fullText = text;
    
    // 只要有历史记录（说明处于追问或连续对话中），就进行拼接
    if (_lastRawText != null && _lastRawText!.isNotEmpty) {
      // 追问模式：拼接历史
      fullText = '$_lastRawText，$text';
      // 更新历史记录为拼接后的文本，支持连续追问
      _lastRawText = fullText;
    } else {
      // 新会话
      _lastRawText = text;
    }
    
    // 获取当前宠物
    final petState = ref.read(petProvider);
    final result = await llmService.parse(
      fullText,
      petType: petState.type.label,      // 动物名称，如"猫咪"、"龙"、"独角兽"
      petStyle: petState.type.description, // 性格描述
    );
    
    if (!mounted) return;
    _handleLLMResult(result);
  }

  void _handleLLMResult(LLMResult result) {
    if (!result.valid) {
      // 无法解析
      setState(() {
        _state = VoiceState.asking;
        _petMessage = PetPrompts.randomInvalid;
        _recognizedText = '';
      });
      return;
    }

    // 检查缺失字段 (一次性提示所有缺失项)
    if (result.missingFields.isNotEmpty) {
      String msg;
      
      // 优先使用大模型生成的萌宠话术
      if (result.promptText != null && result.promptText!.isNotEmpty) {
        msg = result.promptText!;
      } else {
        // Fallback: 本地拼接
        final missing = <String>[];
        if (result.isMissingAmount) missing.add('金额');
        if (result.isMissingEvent) missing.add('买了什么');
        if (result.isMissingTime) missing.add('时间');
        
        if (missing.length == 1) {
          if (result.isMissingAmount) {
            msg = PetPrompts.randomMissingAmount;
          } else if (result.isMissingEvent) msg = PetPrompts.randomMissingEvent;
          else msg = '是什么时候花的呀？';
        } else {
          msg = '还缺${missing.join("和")}呢，告诉我吧~';
        }
      }

      setState(() {
        _state = VoiceState.asking;
        _petMessage = msg;
        _recognizedText = '';
      });
      return;
    }

    // 信息完整，显示确认卡
    setState(() {
      _state = VoiceState.confirming;
      _llmResult = result;
      _petMessage = '记好啦！确认一下？';
    });
  }

  Future<void> _saveTransaction() async {
    if (_llmResult == null || _llmResult!.amount == null) return;

    HapticFeedback.heavyImpact();
    // soundService.playCashRegister(); // 暂时屏蔽音效以防 Crash

    try {
      // 解析时间
      DateTime datetime;
      if (_llmResult!.datetime != null) {
        try {
          datetime = DateTime.parse(_llmResult!.datetime!);
        } catch (_) {
          datetime = DateTime.now();
        }
      } else {
        datetime = DateTime.now();
      }

      await ref.read(transactionNotifierProvider.notifier).addTransaction(
        amount: _llmResult!.amount!,
        isExpense: _llmResult!.isExpense,
        category: _llmResult!.category ?? _llmResult!.type ?? '其他',
        categoryType: _llmResult!.type ?? '其他',
        datetime: datetime,
        note: _llmResult!.event,
      );

      // 触发宠物成功动画
      ref.read(petProvider.notifier).onTransactionSuccess();

      // 等待数据刷新后更新小组件
      await Future.delayed(const Duration(milliseconds: 500));
      await _updateWidget();

      // 清理状态
      _pendingAmount = null;
      _pendingEvent = null;
      _lastRawText = null;
      
      // 成功后自动关闭
      if (mounted) {
        await _close();
      }
    } catch (e) {
      print('Voice save transaction failed: $e');
      if (mounted) {
        setState(() {
          _state = VoiceState.error;
          _petMessage = '保存失败了...';
        });
      }
    }
  }

  /// 更新小组件数据
  Future<void> _updateWidget() async {
    try {
      final petState = ref.read(petProvider);
      final themeMode = ref.read(themeProvider);
      
      // 判断当前是否应该是深色模式
      bool isDark = false;
      if (themeMode == AppThemeMode.dark) {
        isDark = true;
      } else if (themeMode == AppThemeMode.auto) {
        final hour = DateTime.now().hour;
        if (hour >= 23 || hour < 7) {
          isDark = true;
        }
      }

      // 直接从数据库获取最新数据，避免缓存延迟
      final db = ref.read(databaseProvider);
      final todayExpense = await db.getTodayExpenseTotal();
      final monthExpense = await db.getCurrentMonthExpenseTotal();
      
      await WidgetService.updateWidget(
        petImagePath: petState.type.assetPath,
        petType: petState.type.name,
        petMessage: petState.message,
        todayExpense: todayExpense,
        monthExpense: monthExpense,
        isDark: isDark,
      );
    } catch (e) {
      print('Voice overlay widget update failed: $e');
    }
  }
}
