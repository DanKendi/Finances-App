import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/providers.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';
import '../../database/app_database.dart';
import '../../main.dart';
import '../add_transaction/edit_transaction_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Transaction t,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deletar transação'),
        content: Text('Deseja deletar "${t.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(databaseProvider);
      await db.transactionDao.deleteTransactionById(t.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsByMonthProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      body: categoriesAsync.when(
        data: (categories) {
          final categoryMap = {for (final c in categories) c.id: c};

          return transactionsAsync.when(
            data: (transactions) {
              final grouped = <String, List<Transaction>>{};
              for (final t in transactions) {
                final key = formatDate(t.date);
                grouped.putIfAbsent(key, () => []).add(t);
              }

              return CustomScrollView(
                slivers: [
                  // Header com saldo
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Histórico',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          _MonthlyBalanceCard(),
                        ],
                      ),
                    ),
                  ),

                  if (transactions.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Nenhuma transação registrada ainda.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == grouped.length) {
                            return const SizedBox(height: 100);
                          }
                          final dateKey = grouped.keys.elementAt(index);
                          final dayTransactions = grouped[dateKey]!;
                          final dayExpenses = dayTransactions
                              .where((t) => t.isExpense)
                              .fold(0.0, (sum, t) => sum + t.amount);
                          final dayIncome = dayTransactions
                              .where((t) => !t.isExpense)
                              .fold(0.0, (sum, t) => sum + t.amount);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dateKey,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                    Row(
                                      children: [
                                        if (dayIncome > 0)
                                          Text(
                                            '+${formatCurrency(dayIncome)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                    color: Colors.greenAccent
                                                        .shade400),
                                          ),
                                        if (dayIncome > 0 && dayExpenses > 0)
                                          const Text('  '),
                                        if (dayExpenses > 0)
                                          Text(
                                            '-${formatCurrency(dayExpenses)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                    color: Colors.redAccent),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ...dayTransactions.map((t) {
                                final category = categoryMap[t.categoryId];
                                final color = category != null
                                    ? hexToColor(category.color)
                                    : Colors.grey;
                                final icon = category != null
                                    ? (categoryIcons[category.icon] ??
                                        Icons.category)
                                    : Icons.category;

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  child: ListTile(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditTransactionScreen(
                                                transaction: t),
                                      ),
                                    ),
                                    onLongPress: () =>
                                        _confirmDelete(context, ref, t),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          color.withOpacity(0.2),
                                      child:
                                          Icon(icon, color: color, size: 20),
                                    ),
                                    title: Text(t.description),
                                    subtitle: Row(
                                      children: [
                                        if (category != null)
                                          Text(
                                            category.name,
                                            style: TextStyle(
                                                color: color, fontSize: 12),
                                          ),
                                        if (t.totalInstallments != null) ...[
                                          const Text(' · ',
                                              style: TextStyle(
                                                  color: Colors.grey)),
                                          Icon(
                                            t.isRecurring
                                                ? Icons.repeat
                                                : Icons.credit_card,
                                            size: 11,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${t.installmentNumber}/${t.totalInstallments}x',
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12),
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${t.isExpense ? '-' : '+'}${formatCurrency(t.amount)}',
                                          style: TextStyle(
                                            color: t.isExpense
                                                ? Colors.redAccent
                                                : Colors.greenAccent.shade400,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.chevron_right,
                                            color: Colors.grey, size: 16),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                        childCount: grouped.length + 1,
                      ),
                    ),
                ],
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

class _MonthlyBalanceCard extends ConsumerWidget {
  const _MonthlyBalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthlyTotal = ref.watch(monthlyTotalProvider);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);
    final monthlyBalance = ref.watch(monthlyBalanceProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seletor de mês
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  ref.read(selectedMonthProvider.notifier).state = DateTime(
                    selectedMonth.year,
                    selectedMonth.month - 1,
                  );
                },
                icon: const Icon(Icons.chevron_left),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                formatMonth(selectedMonth),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              IconButton(
                onPressed: () {
                  ref.read(selectedMonthProvider.notifier).state = DateTime(
                    selectedMonth.year,
                    selectedMonth.month + 1,
                  );
                },
                icon: const Icon(Icons.chevron_right),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(height: 20),

          // Receitas, Gastos e Saldo
          Row(
            children: [
              // Receitas
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receitas',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12)),
                    const SizedBox(height: 4),
                    monthlyIncome.when(
                      data: (v) => Text(
                        '+${formatCurrency(v)}',
                        style: TextStyle(
                          color: Colors.greenAccent.shade400,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      loading: () => const SizedBox(),
                      error: (e, _) => const SizedBox(),
                    ),
                  ],
                ),
              ),

              // Gastos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gastos',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12)),
                    const SizedBox(height: 4),
                    monthlyTotal.when(
                      data: (v) => Text(
                        '-${formatCurrency(v)}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      loading: () => const SizedBox(),
                      error: (e, _) => const SizedBox(),
                    ),
                  ],
                ),
              ),

              // Saldo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saldo',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12)),
                    const SizedBox(height: 4),
                    monthlyBalance.when(
                      data: (v) {
                        final isPositive = v >= 0;
                        return Text(
                          '${isPositive ? '+' : ''}${formatCurrency(v)}',
                          style: TextStyle(
                            color: isPositive
                                ? Colors.greenAccent.shade400
                                : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        );
                      },
                      loading: () => const SizedBox(),
                      error: (e, _) => const SizedBox(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}