import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/pet/pet_card.dart';
import '../../widgets/transaction/transaction_list.dart';

/// 首页 - "温馨的家"
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petState = ref.watch(petProvider);
    final budgetRatio = ref.watch(budgetRatioProvider);
    final todayExpense = ref.watch(todayExpenseTotalProvider);
    final transactions = ref.watch(transactionNotifierProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 宠物卡片区域
            SliverToBoxAdapter(
              child: PetCard(
                petState: petState,
                budgetRatio: budgetRatio.when(
                  data: (ratio) => ratio,
                  loading: () => 1.0,
                  error: (_, __) => 1.0,
                ),
                todayExpense: todayExpense.when(
                  data: (amount) => amount,
                  loading: () => 0.0,
                  error: (_, __) => 0.0,
                ),
                onTap: () => ref.read(petProvider.notifier).onTap(),
              ),
            ),
            
            // 流水列表
            // 流水列表
            // 使用自定义逻辑以避免刷新时的闪烁：如果正在加载但已有数据，继续显示旧数据
            if (transactions.isLoading && !transactions.hasValue)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (transactions.hasError && !transactions.hasValue)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    '加载失败: ${transactions.error}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              TransactionList(transactions: transactions.value ?? []),
          ],
        ),
      ),
    );
  }
}
