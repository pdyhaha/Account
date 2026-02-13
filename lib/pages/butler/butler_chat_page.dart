import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../core/theme/colors.dart';
import '../../services/llm_service.dart';
import '../../providers/database_provider.dart';
import '../../providers/pet_provider.dart';

class ButlerChatPage extends ConsumerStatefulWidget {
  const ButlerChatPage({super.key});

  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ButlerChat',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => const ButlerChatPage(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      useRootNavigator: true,
    );
  }

  @override
  ConsumerState<ButlerChatPage> createState() => _ButlerChatPageState();
}

class _ButlerChatPageState extends ConsumerState<ButlerChatPage> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  
  // 键盘动画控制
  double _inputOpacity = 1.0;
  Timer? _debounceTimer;
  double _lastBottomInset = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 初始问候
    _addMessage(ChatMessage(
      role: 'butler',
      content: '主人，我是您的专属理财管家~ 想要了解最近的收支情况吗？您可以问我：\n"这个月花了多少钱？"\n"最近在哪方面花钱最多？"',
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = View.of(context).viewInsets.bottom;
    
    // 如果键盘高度发生显著变化，说明正在动画中
    if ((bottomInset - _lastBottomInset).abs() > 1.0) {
      if (_inputOpacity != 0.0) {
        setState(() {
          _inputOpacity = 0.0; // 立即隐藏
        });
      }
      
      // 防抖：动画停止后显示
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _inputOpacity = 1.0;
            _lastBottomInset = bottomInset;
          });
        }
      });
    } else {
      _lastBottomInset = bottomInset;
    }
  }

  void _addMessage(ChatMessage msg) {
    setState(() {
      _messages.add(msg);
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0, // 反向列表，0 是底部
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _addMessage(ChatMessage(role: 'user', content: text));
    setState(() => _isLoading = true);

    try {
      // 1. 获取账本数据
      final db = ref.read(databaseProvider);
      final now = DateTime.now();
      
      // 获取本月所有账单用于统计
      final monthTransactions = await db.getCurrentMonthTransactions();
      final totalExpense = monthTransactions.where((t) => t.isExpense).fold(0.0, (sum, t) => sum + t.amount);
      final totalIncome = monthTransactions.where((t) => !t.isExpense).fold(0.0, (sum, t) => sum + t.amount);
      
      // 获取最近 30 天的明细用于回答具体问题
      final start = now.subtract(const Duration(days: 30));
      final recentTransactions = await db.getTransactionsByDateRange(start, now);
      
      // 构建分类统计
      final categoryStats = <String, double>{};
      for (var t in monthTransactions.where((t) => t.isExpense)) {
        categoryStats[t.categoryType] = (categoryStats[t.categoryType] ?? 0) + t.amount;
      }
      final sortedCategories = categoryStats.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topCategories = sortedCategories.take(3).map((e) => '${e.key}(${e.value.toStringAsFixed(0)}元)').join('、');

      // 2. 构建数据摘要
      String formatT(var t) {
        final time = "${t.datetime.hour.toString().padLeft(2,'0')}:${t.datetime.minute.toString().padLeft(2,'0')}";
        final date = "${t.datetime.month}/${t.datetime.day}";
        return "[$date $time] ${t.category}(${t.categoryType}): ${t.amount}元";
      }

      final expenseList = recentTransactions
          .where((t) => t.isExpense)
          .take(40)
          .map(formatT)
          .join('\n');
      
      final incomeList = recentTransactions
          .where((t) => !t.isExpense)
          .take(20)
          .map(formatT)
          .join('\n');

      final pet = ref.read(petProvider);
      final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final dateStr = "${now.year}年${now.month}月${now.day}日 ${weekdays[now.weekday - 1]} ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}";

      // 3. 构建对话历史（不包含初始问候和当前正在发送的消息）
      final historyMessages = _messages.where((m) => 
        m.role != 'system' && 
        !(m.role == 'butler' && m.content.contains('我是您的专属理财管家'))
      ).toList();
      
      final conversationHistory = historyMessages.isEmpty 
          ? '' 
          : historyMessages.map((m) => '${m.role == 'user' ? '主人' : '管家'}：${m.content}').join('\n');

      // 4. 构建 Prompt
      final prompt = '''
当前时间：$dateStr

【本月财务概况】
总支出：${totalExpense.toStringAsFixed(2)}元
总收入：${totalIncome.toStringAsFixed(2)}元
支出大头：${topCategories.isEmpty ? '暂无' : topCategories}

【最近30天账本明细】
支出：
${expenseList.isEmpty ? '暂无记录' : expenseList}

收入：
${incomeList.isEmpty ? '暂无记录' : incomeList}

${conversationHistory.isNotEmpty ? '''
【本次对话历史】
$conversationHistory
''' : ''}
主人：$text

【指令】
1. 你是"${pet.type.label}"，我的专属财务管家。
2. 请根据提供的账本数据和对话历史回答主人的最新问题。
3. 如果用户问日期/今天几号，请基于"当前时间"回答。
4. 回复要简短、准确，带有${pet.type.label}的可爱语气（如喵、汪、吼等）。
5. 如果数据中没有相关信息，请诚实告知并撒个娇。
6. 注意保持对话的连贯性，可以参考之前的对话内容。
''';

      // 5. 调用 LLM
      final response = await llmService.chat(
        prompt, 
        petType: pet.type.label,
      );

      _addMessage(ChatMessage(
        role: 'butler', 
        content: response ?? '哎呀，网络好像开小差了，没听到主人说什么~'
      ));

    } catch (e) {
      _addMessage(ChatMessage(role: 'butler', content: '管家遇到了一点小错误：$e'));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取底部安全区和键盘高度
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
        children: [
          // 顶部拖动手柄
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '专属管家',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true, // 反向列表，键盘弹出时自动顶起
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      // 反向获取消息，最新的在底部（index=0）
                      final msg = _messages[_messages.length - 1 - index];
                      final isUser = msg.role == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.sky : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                              bottomLeft: !isUser ? Radius.zero : const Radius.circular(16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            msg.content,
                            style: TextStyle(
                              color: isUser 
                                  ? Colors.black 
                                  : Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('管家正在思考...', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8) ?? AppColors.textSecondary, fontSize: 12)),
                  ),
                
                // 输入区域
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _inputOpacity,
                  curve: Curves.easeOut,
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 16, 
                      right: 16, 
                      top: 16, 
                      bottom: 16 + (viewInsetsBottom > 0 ? 0 : bottomPadding)
                    ),
                    margin: EdgeInsets.only(bottom: viewInsetsBottom),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      boxShadow: [
                         BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            decoration: InputDecoration(
                              hintText: '问问我最近花了多少钱...',
                              hintStyle: TextStyle(
                                color: Theme.of(context).hintColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Theme.of(context).scaffoldBackgroundColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onSubmitted: (_) => _handleSend(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _handleSend,
                          icon: const Icon(Icons.send_rounded, color: AppColors.sky),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    ),
    );
  }
}

class ChatMessage {
  final String role;
  final String content;
  ChatMessage({required this.role, required this.content});
}
