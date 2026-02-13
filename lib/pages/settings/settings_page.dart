import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:image_picker/image_picker.dart';
import '../../widgets/common/image_crop_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:drift/native.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../data/database/app_database.dart';
import '../../providers/budget_provider.dart';
import '../../providers/pet_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/stats_provider.dart';
import '../butler/butler_chat_page.dart';

import '../../services/webdav_service.dart';
import '../../services/background_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/theme_mask_provider.dart';
import 'dart:ui';
import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/dialog_helper.dart';
import '../../core/utils/pet_helper.dart';
import '../../widgets/common/numeric_keyboard.dart';

/// 设置页面 - "管家中心"
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> 
    with SingleTickerProviderStateMixin {
  int _easterEggTapCount = 0;
  bool _isLoading = false;
  
  // 宠物入场动画
  late AnimationController _petAnimController;
  late Animation<double> _petScaleAnimation;

  @override
  void initState() {
    super.initState();
    // 宠物弹跳动画：弹起后落下静止
    _petAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _petScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 0.9)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_petAnimController);
    
    // 延迟开始动画
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _petAnimController.forward();
    });
  }

  @override
  void dispose() {
    _petAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetAsync = ref.watch(currentBudgetProvider);
    final petState = ref.watch(petProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 顶部 App Bar
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '⚙️',
                        style: TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '管家中心',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).textTheme.headlineSmall?.color ?? AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 内容
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 宠物卡片
                      _buildPetCard(petState),

                      const SizedBox(height: 20),

                      // 预算设置
                      _buildSection(
                        title: '💰 预算管理',
                        children: [
                          _buildBudgetTile(budgetAsync),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 宠物设置
                      _buildSection(
                        title: '🐾 宠物设置',
                        children: [
                          _buildPetTypeTile(petState),
                          _buildDivider(),
                          _buildTile(
                            icon: Icons.shuffle_rounded,
                            iconColor: AppColors.mint,
                            title: '随机换宠',
                            subtitle: '让命运选择你的小伙伴',
                            trailing: SizedBox(
                              width: 80,
                              child: ElevatedButton(
                                onPressed: () {
                                  ref.read(petProvider.notifier).randomizePet();
                                  HapticFeedback.lightImpact();
                                  
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '换了一只新的${_getPetTypeName(ref.read(petProvider).type)}！',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.mint,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.zero, // Reduce padding for smaller width
                                ),
                                child: const Text('换一只', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 外观设置
                      _buildSection(
                        title: '🎨 外观设置',
                        children: [
                          _buildThemeTile(ref.watch(themeProvider)),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 数据管理
                      _buildSection(
                        title: '📦 数据管理',
                        children: [
                          _buildTile(
                            icon: Icons.cloud_sync_rounded,
                            iconColor: AppColors.sky,
                            title: 'WebDAV 备份',
                            subtitle: '同步数据到坚果云/NAS',
                            onTap: () => _showWebDavDialog(),
                          ),
                          _buildDivider(),
                          _buildTile(
                            icon: Icons.download_rounded,
                            iconColor: AppColors.income,
                            title: '本地导出',
                            subtitle: '保存 JSON 到根目录/LazyDog_Account',
                            onTap: () => _exportData(),
                          ),
                          _buildDivider(),
                          _buildTile(
                            icon: Icons.upload_file_rounded,
                            iconColor: AppColors.lavender,
                            title: '本地恢复',
                            subtitle: '从根目录 JSON 文件恢复',
                            onTap: () => _importData(),
                          ),
                          _buildDivider(),
                          _buildTile(
                            icon: Icons.delete_sweep_rounded,
                            iconColor: AppColors.expense,
                            title: '清空所有数据',
                            subtitle: '请谨慎操作',
                            onTap: () => _showClearDataDialog(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 关于
                      _buildSection(
                        title: '💝 关于',
                        children: [
                          _buildTile(
                            icon: Icons.face_retouching_natural_rounded,
                            iconColor: AppColors.sakura,
                            title: '专属管家',
                            subtitle: '聊聊最近的开销...',
                            onTap: () => ButlerChatPage.show(context),
                          ),
                          _buildDivider(),
                          _buildTile(
                            icon: Icons.info_outline_rounded,
                            iconColor: AppColors.lavender,
                            title: '版本信息',
                            subtitle: 'v520.1314 (PL&CJH)',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.sakura.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '最新版',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.sakura,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 底部留白
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.sakura),
                    SizedBox(height: 16),
                    Text('正在处理中...', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 宠物展示卡片
  Widget _buildPetCard(PetState petState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getMoodGradient(petState.mood),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _getMoodColor(petState.mood).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // 宠物表情（带动画）
          AnimatedBuilder(
            animation: _petScaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _petScaleAnimation.value,
                child: child,
              );
            },
            child: petState.type.isCustom
                ? ClipOval(
                    child: Image.file(
                      File(petState.type.assetPath),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Text('🐾'),
                    ),
                  )
                : Image.asset(
                    PetHelper.getPetImage(petState.type, petState.mood),
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '你的${_getPetTypeName(petState.type)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white 
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  petState.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white.withValues(alpha: 0.7) 
                        : AppColors.textPrimary.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 主题设置 Tile
  Widget _buildThemeTile(AppThemeMode currentMode) {
    String subtitle;
    IconData icon;
    switch (currentMode) {
      case AppThemeMode.auto:
        subtitle = '跟随时间 (23:00-7:00 深色)';
        icon = Icons.brightness_auto_rounded;
        break;
      case AppThemeMode.light:
        subtitle = '浅色模式';
        icon = Icons.wb_sunny_rounded;
        break;
      case AppThemeMode.dark:
        subtitle = '深色模式';
        icon = Icons.nightlight_round;
        break;
    }

    return _buildTile(
      icon: icon,
      iconColor: AppColors.categoryColors['娱乐']!,
      title: '主题模式',
      subtitle: subtitle,
      onTap: () => _showThemeDialog(currentMode),
    );
  }

  /// 主题选择对话框
  void _showThemeDialog(AppThemeMode currentMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('🎨', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Text(
                  '选择主题模式',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).textTheme.titleMedium?.color
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildThemeOption(context, AppThemeMode.auto, '自动 (跟随时间)', Icons.brightness_auto_rounded, currentMode),
            const SizedBox(height: 12),
            _buildThemeOption(context, AppThemeMode.light, '浅色模式', Icons.wb_sunny_rounded, currentMode),
            const SizedBox(height: 12),
            _buildThemeOption(context, AppThemeMode.dark, '深色模式', Icons.nightlight_round, currentMode),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, AppThemeMode mode, String title, IconData icon, AppThemeMode currentMode) {
    final isSelected = mode == currentMode;
    return InkWell(
      onTap: () {
        if (mode == currentMode) {
          Navigator.pop(context);
          return;
        }

        // 1. 同步开启蒙版
        ref.read(themeMaskProvider.notifier).state = true;
        
        // 2. 立即关闭当前弹窗
        Navigator.pop(context);
        
        // 3. 增加延时到 150ms，确保蒙版已经在屏幕上完全绘制并稳定
        // 只有这样才能在下一次 MaterialApp 重建前完全遮住底层
        Future.delayed(const Duration(milliseconds: 150), () {
          ref.read(themeProvider.notifier).setThemeMode(mode);
          
          // 4. 保持 1.5 秒的显示时间，作为平滑过渡
          Future.delayed(const Duration(milliseconds: 1500), () {
            ref.read(themeMaskProvider.notifier).state = false;
          });
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
            const SizedBox(width: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  /// 预算设置 Tile
  Widget _buildBudgetTile(AsyncValue<Budget?> budgetAsync) {
    return budgetAsync.when(
      data: (budget) => _buildTile(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: AppColors.warning,
        title: '月度预算',
        subtitle: budget != null
            ? '当前预算: ¥${budget.amount.toStringAsFixed(0)}'
            : '未设置预算',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            budget != null ? '修改' : '设置',
            style: const TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        onTap: () => _showBudgetDialog(budget?.amount),
      ),
      loading: () => _buildTile(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: AppColors.warning,
        title: '月度预算',
        subtitle: '加载中...',
      ),
      error: (_, __) => _buildTile(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: AppColors.warning,
        title: '月度预算',
        subtitle: '加载失败',
      ),
    );
  }

  /// 宠物类型选择 Tile
  Widget _buildPetTypeTile(PetState petState) {
    return _buildTile(
      icon: Icons.pets_rounded,
      iconColor: AppColors.sakura,
      title: '切换宠物',
      subtitle: '当前: ${_getPetTypeName(petState.type)}',
      onTap: () => _showPetTypeDialog(petState.type),
    );
  }

  /// 预算设置对话框
  void _showBudgetDialog(double? currentBudget) {
    String amountStr = currentBudget?.toStringAsFixed(0) ?? '';

    DialogHelper.showButlerBottomSheet(
      context: context,
      heightFactor: null, // 自适应高度
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.sakura.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('💰', style: TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '设置月度预算',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '设置预算后，宠物会展示对应心情哦',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 金额显示
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.sakura.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '¥',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.sakura.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              amountStr.isEmpty ? '0' : amountStr,
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: amountStr.isEmpty 
                                  ? Theme.of(context).hintColor.withValues(alpha: 0.3)
                                  : Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          if (amountStr.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setModalState(() => amountStr = '');
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 快捷金额
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [3000, 5000, 8000, 10000, 15000].map((amount) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text('¥$amount'),
                              backgroundColor: amountStr == amount.toString()
                                  ? AppColors.sakura.withValues(alpha: 0.2)
                                  : Theme.of(context).cardColor,
                              side: BorderSide(
                                color: amountStr == amount.toString()
                                    ? AppColors.sakura
                                    : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                              ),
                              labelStyle: TextStyle(
                                color: amountStr == amount.toString()
                                    ? AppColors.sakura
                                    : Theme.of(context).textTheme.bodyMedium?.color,
                                fontWeight: amountStr == amount.toString() ? FontWeight.bold : FontWeight.normal,
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => amountStr = amount.toString());
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // 自定义数字键盘
              NumericKeyboard(
                doneLabel: '确定',
                onKeyPressed: (key) {
                  if (amountStr.length >= 7) return; // 限制长度
                  setModalState(() {
                    if (amountStr == '0') {
                      amountStr = key;
                    } else {
                      amountStr += key;
                    }
                  });
                },
                onDeletePressed: () {
                  if (amountStr.isNotEmpty) {
                    setModalState(() {
                      amountStr = amountStr.substring(0, amountStr.length - 1);
                    });
                  }
                },
                onClearPressed: () {
                  setModalState(() => amountStr = '');
                },
                onDonePressed: () async {
                  if (amountStr.isEmpty) {
                    Navigator.pop(context);
                    return;
                  }
                  
                  final amount = double.tryParse(amountStr);
                  if (amount != null && amount > 0) {
                    await ref
                        .read(budgetNotifierProvider.notifier)
                        .setCurrentMonthBudget(amount);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('预算已设置为 ¥${amount.toStringAsFixed(0)}'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: AppColors.sakura,
                        ),
                      );
                    }
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// 宠物类型选择对话框
  void _showPetTypeDialog(PetType currentType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    DialogHelper.showButlerBottomSheet(
      context: context,
      heightFactor: 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🐾', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  '选择你的萌宠',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 宠物网格列表
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final petState = ref.watch(petProvider);
                final allPets = petState.allPets;
                
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: allPets.length + 1, // +1 for Add button
                  padding: const EdgeInsets.only(bottom: 34, left: 16, right: 16), // 底部安全距离
                  itemBuilder: (context, index) {
                    // Add button at the end
                    if (index == allPets.length) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _pickCustomPetImage();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.cream,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                              style: BorderStyle.solid,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.grey.withValues(alpha: 0.8)),
                              const SizedBox(height: 8),
                              Text(
                                '添加自定义',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final type = allPets[index];
                    final isSelected = type == petState.type;
                    
                    return GestureDetector(
                      onDoubleTap: type.isCustom ? () {
                          // Double tap to delete custom pet
                          _showDeleteCustomPetDialog(type);
                      } : null,
                      onTap: () {
                        ref.read(petProvider.notifier).switchPetType(type);
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已切换为${type.label}！'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.sakura.withValues(alpha: 0.15)
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.cream),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.sakura : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (type.isCustom)
                              ClipOval(
                                child: Image.file(
                                  File(type.assetPath),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Text('🐾'),
                                ),
                              )
                            else
                              Image.asset(
                                PetHelper.getPetImage(type, PetMood.happy), // 使用 happy 状态
                                width: 60,
                                height: 60,
                                fit: BoxFit.contain,
                              ),
                            const SizedBox(height: 8),
                            Text(
                              type.label,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected 
                                    ? AppColors.sakura 
                                    : (isDark ? Colors.white70 : AppColors.textPrimary),
                                fontSize: 12,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.sakura,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '当前',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// WebDAV 配置及备份恢复对话框
  void _showWebDavDialog() {
    showDialog(
      context: context,
      builder: (context) => _WebDavMainDialog(),
    );
  }

  /// 请求存储权限
  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // 1. 对于 Android 11+，申请 MANAGE_EXTERNAL_STORAGE
    // 这允许访问根目录（如 /storage/emulated/0/LazyDog_Account）
    bool hasManagePermission = await Permission.manageExternalStorage.isGranted;
    if (!hasManagePermission) {
      final status = await Permission.manageExternalStorage.request();
      hasManagePermission = status.isGranted;
    }

    if (hasManagePermission) return true;

    // 2. 如果不给管理权限，尝试申请普通的 storage 权限 (主要针对 Android 10 及以下)
    bool hasStoragePermission = await Permission.storage.isGranted;
    if (!hasStoragePermission) {
      final status = await Permission.storage.request();
      hasStoragePermission = status.isGranted;
    }

    if (hasStoragePermission) return true;

    // 3. 如果都被拒绝了，检查是否被永久拒绝，引导去设置
    if (await Permission.manageExternalStorage.isPermanentlyDenied || 
        await Permission.storage.isPermanentlyDenied) {
      if (mounted) {
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('权限受限'),
            content: const Text('导出/导入功能需要“所有文件访问”权限。请在系统设置中手动开启。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('去开启')),
            ],
          ),
        );
        if (openSettings == true) {
          await openAppSettings();
        }
      }
    }
    
    return false;
  }

  /// 导出数据
  Future<void> _exportData() async {
    setState(() => _isLoading = true);
    try {
      // 1. 申请权限
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('未获得存储权限，无法导出文件'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 2. 准备数据
      final db = ref.read(databaseProvider);
      final data = await db.exportAllData();
      final json = const JsonEncoder.withIndent('  ').convert(data);

      // 3. 确定路径
      String rootPath;
      if (Platform.isAndroid) {
        rootPath = '/storage/emulated/0';
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        rootPath = docDir.path;
      }
      
      final exportDir = Directory('$rootPath/LazyDog_Account');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // 仅输出日期作为文件名，实现当日覆盖
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final file = File('${exportDir.path}/pet_ledger_export_$dateStr.json');
      await file.writeAsString(json);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('数据已导出到: ${file.path.replaceAll('/storage/emulated/0', '')}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.income,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 恢复数据
  Future<void> _importData() async {
    try {
      // 1. 申请权限
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('未获得存储权限，无法读取备份文件'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 2. 检查目录
      String rootPath;
      if (Platform.isAndroid) {
        rootPath = '/storage/emulated/0';
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        rootPath = docDir.path;
      }
      
      final exportDir = Directory('$rootPath/LazyDog_Account');
      if (!await exportDir.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('未找到备份目录: /LazyDog_Account/'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 3. 获取目录下最新的 json 文件
      final files = exportDir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
          ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('备份目录下没有找到 JSON 文件'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final latestFile = files.first;
      
      if (mounted) {
        // 4. 确认对话框
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('恢复数据'),
            content: Text('是否从最新备份恢复？\n\n文件: ${latestFile.path.split('/').last}\n修改时间: ${DateFormat('yyyy-MM-dd HH:mm').format(latestFile.lastModifiedSync())}\n\n注意：当前手机内的数据将被覆盖！'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.lavender),
                child: const Text('确认恢复'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        setState(() => _isLoading = true);
        
        final jsonStr = await latestFile.readAsString();
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        
        final db = ref.read(databaseProvider);
        await db.importAllData(data);
        
        // 刷新所有相关 Provider
        _invalidateAllProviders();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('数据恢复成功！'), 
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.income,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('恢复失败: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 刷新所有 Provider
  void _invalidateAllProviders() {
    ref.invalidate(transactionsProvider);
    ref.invalidate(transactionNotifierProvider);
    ref.invalidate(todayTransactionsProvider);
    ref.invalidate(todayExpenseTotalProvider);
    ref.invalidate(currentMonthTransactionsProvider);
    ref.invalidate(currentMonthExpenseTotalProvider);
    ref.invalidate(latestTransactionProvider);
    ref.invalidate(monthlyStatsProvider);
    ref.invalidate(categoryStatsProvider);
    ref.invalidate(categoryExpenseProvider);
    ref.invalidate(spendingRankingProvider);
    ref.invalidate(dailyComparisonProvider);
    ref.invalidate(weeklyTrendProvider);
    ref.invalidate(currentMonthIncomeTotalProvider);
    ref.invalidate(currentBudgetProvider);
    ref.invalidate(budgetRatioProvider);
    ref.read(petProvider.notifier).refresh();
  }

  /// 清空数据确认对话框
  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('⚠️', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('确认清空?'),
          ],
        ),
        content: const Text(
          '此操作将删除所有账单记录、预算设置等数据，且无法恢复。\n\n'
          '建议先导出数据备份。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(databaseProvider).clearAllData();
              
              // 刷新所有相关 Provider
              ref.invalidate(transactionsProvider);
              ref.invalidate(transactionNotifierProvider);
              ref.invalidate(todayTransactionsProvider);
              ref.invalidate(todayExpenseTotalProvider);
              ref.invalidate(currentMonthTransactionsProvider);
              ref.invalidate(currentMonthExpenseTotalProvider);
              ref.invalidate(latestTransactionProvider);
              
              ref.invalidate(monthlyStatsProvider);
              ref.invalidate(categoryStatsProvider);
              ref.invalidate(categoryExpenseProvider);
              ref.invalidate(spendingRankingProvider);
              ref.invalidate(dailyComparisonProvider);
              ref.invalidate(weeklyTrendProvider);
              ref.invalidate(currentMonthIncomeTotalProvider);
              
              ref.invalidate(currentBudgetProvider);
              ref.invalidate(budgetRatioProvider);
              
              // 刷新宠物状态
              ref.read(petProvider.notifier).refresh();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('所有数据已清空'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }

  /// 构建通用设置项 Tile
  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  /// 构建设置分块
  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 56,
      endIndent: 16,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
    );
  }

  String _getPetTypeName(PetType type) {
    if (type.isCustom) return type.label;
    
    // 兼容旧的映射逻辑，如果 PetType 自身有 label 则优先使用
    if (type.label.isNotEmpty) return type.label;

    switch (type.name) {
      case 'cat': return '猫咪';
      case 'dog': return '狗狗';
      case 'bunny': return '兔子';
      case 'duck': return '鸭鸭';
      case 'hamster': return '仓鼠';
      default: return '宠物';
    }
  }

  Future<void> _pickCustomPetImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile == null || !mounted) return;

    // 显示裁剪对话框
    final croppedFile = await showDialog<File>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImageCropDialog(imageFile: File(pickedFile.path)),
    );

    if (croppedFile == null || !mounted) return;

    // 弹出命名对话框
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('给新伙伴起个名'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: '例如：旺财',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    final petName = nameController.text.trim();
    if (petName.isEmpty) return;

    // 保存文件到本地
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'custom_pet_${DateTime.now().millisecondsSinceEpoch}.png';
    final savedImage = await croppedFile.copy('${appDir.path}/$fileName');

    // 添加到 Provider
    final newPet = PetType(
      name: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      label: petName,
      assetPath: savedImage.path,
      description: '独一无二的伙伴',
      isCustom: true,
    );

    await ref.read(petProvider.notifier).addCustomPet(newPet);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('欢迎【$petName】来到新家！'),
          backgroundColor: AppColors.sakura,
        ),
      );
    }
  }

  void _showDeleteCustomPetDialog(PetType pet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除宠物'),
        content: Text('确定要送走【${pet.label}】吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(petProvider.notifier).removeCustomPet(pet.name);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Color _getMoodColor(PetMood mood) {
    switch (mood) {
      case PetMood.happy:
        return AppColors.moodHappy;
      case PetMood.normal:
        return AppColors.moodNormal;
      case PetMood.worry:
        return AppColors.moodWorry;
      case PetMood.sad:
        return AppColors.moodSad;
    }
  }

  List<Color> _getMoodGradient(PetMood mood) {
    switch (mood) {
      case PetMood.happy:
        return [AppColors.moodHappy.withValues(alpha: 0.1), AppColors.moodHappy.withValues(alpha: 0.3)];
      case PetMood.normal:
        return [AppColors.moodNormal.withValues(alpha: 0.1), AppColors.moodNormal.withValues(alpha: 0.3)];
      case PetMood.worry:
        return [AppColors.moodWorry.withValues(alpha: 0.1), AppColors.moodWorry.withValues(alpha: 0.3)];
      case PetMood.sad:
        return [AppColors.moodSad.withValues(alpha: 0.1), AppColors.moodSad.withValues(alpha: 0.3)];
    }
  }
}

class _WebDavMainDialog extends StatefulWidget {
  @override
  State<_WebDavMainDialog> createState() => _WebDavMainDialogState();
}

class _WebDavMainDialogState extends State<_WebDavMainDialog> {
  final _serverController = TextEditingController();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isAdding = false;
  bool _showRestoreList = false;
  List<webdav.File> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadActiveAccount();
  }

  Future<void> _loadActiveAccount() async {
    await webDavService.initialize();
    final account = webDavService.activeAccount;
    if (mounted) {
      setState(() {
        if (account != null) {
          _serverController.text = account.url;
          _userController.text = account.user;
          _passwordController.text = account.password;
        } else {
          _serverController.text = 'https://dav.jianguoyun.com/dav/';
        }
      });
    }
  }

  Future<void> _backup() async {
    setState(() => _isLoading = true);
    try {
      if (!webDavService.isLoggedIn || _isAdding) {
        await webDavService.login(_serverController.text, _userController.text, _passwordController.text);
      }
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'pet_ledger.db'));
      await webDavService.uploadDatabase(dbFile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('备份成功！'), backgroundColor: AppColors.income));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRestoreList() async {
    setState(() => _isLoading = true);
    try {
      if (!webDavService.isLoggedIn || _isAdding) {
        await webDavService.login(_serverController.text, _userController.text, _passwordController.text);
      }
      final list = await webDavService.getBackupList(currentDeviceOnly: false);
      if (mounted) {
        setState(() {
          _backups = list;
          _showRestoreList = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('获取列表失败: $e')));
      }
    }
  }

  String _formatFileName(String name) {
    final regExp = RegExp(r'\d{8}');
    final match = regExp.firstMatch(name);
    if (match != null) {
      final date = match.group(0)!;
      return '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)} 备份';
    }
    return name;
  }

  String _getShortUser(String user) {
    if (user.contains('@')) {
      return user.split('@')[0];
    }
    return user;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = webDavService.accounts;
    final activeAccount = webDavService.activeAccount;

    return AlertDialog(
      title: Text(_showRestoreList ? '选择备份恢复' : 'WebDAV 备份'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading 
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 40),
                CircularProgressIndicator(),
                SizedBox(height: 40),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_showRestoreList) ...[
                    if (_backups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text('云端没有找到备份文件', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _backups.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final f = _backups[index];
                            final dateStr = f.mTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(f.mTime!) : '';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(_formatFileName(f.name ?? '未知备份'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              subtitle: Text(dateStr, style: const TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.restore_rounded, size: 20, color: AppColors.lavender),
                              onTap: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('确认恢复'),
                                    content: Text('要恢复备份 ${_formatFileName(f.name ?? "")} 吗？'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('恢复')),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  try {
                                    final dbPath = p.join((await getApplicationDocumentsDirectory()).path, 'pet_ledger.db');
                                    await webDavService.downloadDatabase(dbPath, remoteFilePath: f.path);
                                    if (context.mounted) {
                                      Navigator.pop(context); // Close main dialog
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('恢复成功！数据已更新')));
                                    }
                                  } catch (e) {
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失败: $e')));
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _showRestoreList = false),
                      child: const Text('返回配置'),
                    ),
                  ] else ...[
                    if (!_isAdding && accounts.isNotEmpty) ...[
                      const Text('选择账号', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      ...accounts.map((acc) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Radio<String>(
                          value: acc.id,
                          groupValue: activeAccount?.id,
                          activeColor: AppColors.sky,
                          onChanged: (val) async {
                            if (val != null) {
                              await webDavService.switchAccount(val);
                              _loadActiveAccount();
                            }
                          },
                        ),
                        title: Text(_getShortUser(acc.user), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text(acc.url, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                          onPressed: () async {
                            await webDavService.deleteAccount(acc.id);
                            _loadActiveAccount();
                          },
                        ),
                      )),
                      TextButton.icon(
                        onPressed: () => setState(() => _isAdding = true),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('添加新账号'),
                      ),
                    ] else ...[
                      const Text('配置 WebDAV 账号', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(controller: _serverController, decoration: const InputDecoration(labelText: '服务器地址', isDense: true, hintText: 'https://dav.jianguoyun.com/dav/')),
                      TextField(controller: _userController, decoration: const InputDecoration(labelText: '账号', isDense: true)),
                      TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: '应用密码', isDense: true)),
                      if (accounts.isNotEmpty)
                        TextButton(onPressed: () => setState(() => _isAdding = false), child: const Text('返回选择')),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    ElevatedButton.icon(
                      onPressed: _backup,
                      icon: const Icon(Icons.cloud_upload_rounded),
                      label: const Text('立即备份当前数据'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.sky, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _fetchRestoreList,
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('恢复历史备份'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ],
                ],
              ),
            ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
      ],
    );
  }
}
