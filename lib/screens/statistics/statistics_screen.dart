import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/providers.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final transactionsAsync = ref.watch(transactionsByMonthProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final monthlyTotal = ref.watch(monthlyTotalProvider);
    final expensesByCategory = ref.watch(expensesByCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
              ),
              Text(
                formatMonth(selectedMonth),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                onPressed: () {
                  ref.read(selectedMonthProvider.notifier).state = DateTime(
                    selectedMonth.year,
                    selectedMonth.month + 1,
                  );
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Card total do mês
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Total gasto no mês',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  monthlyTotal.when(
                    data: (total) => Text(
                      formatCurrency(total),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('Erro: $e'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Gráfico de rosca
          categoriesAsync.when(
            data: (categories) {
              final categoryMap = {for (final c in categories) c.id: c};

              return expensesByCategory.when(
                data: (expMap) {
                  if (expMap.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'Nenhum gasto neste mês',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  }

                  final total =
                      expMap.values.fold(0.0, (sum, v) => sum + v);

                  final sections = expMap.entries.map((entry) {
                    final category = categoryMap[entry.key];
                    final color = category != null
                        ? hexToColor(category.color)
                        : Colors.grey;
                    final percentage = (entry.value / total) * 100;

                    return PieChartSectionData(
                      value: entry.value,
                      color: color,
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList();

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Gastos por categoria',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 220,
                            child: PieChart(
                              PieChartData(
                                sections: sections,
                                centerSpaceRadius: 48,
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Legenda
                          ...expMap.entries.map((entry) {
                            final category = categoryMap[entry.key];
                            final color = category != null
                                ? hexToColor(category.color)
                                : Colors.grey;
                            final icon = category != null
                                ? (categoryIcons[category.icon] ??
                                    Icons.category)
                                : Icons.category;
                            final percentage =
                                (entry.value / total) * 100;

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor:
                                        color.withOpacity(0.2),
                                    child: Icon(icon,
                                        color: color, size: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        category?.name ?? 'Outros'),
                                  ),
                                  Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style:
                                        const TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatCurrency(entry.value),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Center(
                    child: CircularProgressIndicator()),
                error: (e, _) => Text('Erro: $e'),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erro: $e'),
          ),

          const SizedBox(height: 16),

          // Lista de gastos do mês
          transactionsAsync.when(
          data: (transactions) {
            final expenses = transactions.where((t) => t.isExpense).toList();
            if (expenses.isEmpty) return const SizedBox();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gastos do mês',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...expenses.map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(t.description,
                                      overflow: TextOverflow.ellipsis)),
                              Text(
                                formatCurrency(t.amount),
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            );
          },
            loading: () => const SizedBox(),
            error: (e, _) => Text('Erro: $e'),
          ),
        ],
      ),
    );
  }
}