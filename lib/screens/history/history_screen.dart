import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/providers.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';
import '../../database/app_database.dart';
import '../add_transaction/edit_transaction_screen.dart';
import '../../main.dart';

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
        title: const Text('Deletar gasto'),
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
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        centerTitle: false,
      ),
      body: categoriesAsync.when(
        data: (categories) {
          final categoryMap = {for (final c in categories) c.id: c};

          return transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Nenhum gasto registrado ainda.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final grouped = <String, List<Transaction>>{};
              for (final t in transactions) {
                final key = formatDate(t.date);
                grouped.putIfAbsent(key, () => []).add(t);
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final dateKey = grouped.keys.elementAt(index);
                  final dayTransactions = grouped[dateKey]!;
                  final dayTotal = dayTransactions
                      .where((t) => t.isExpense)
                      .fold(0.0, (sum, t) => sum + t.amount);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateKey,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                            Text(
                              formatCurrency(dayTotal),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: Colors.redAccent),
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
                            ? (categoryIcons[category.icon] ?? Icons.category)
                            : Icons.category;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditTransactionScreen(transaction: t),
                                ),
                              );
                            },
                            onLongPress: () =>
                                _confirmDelete(context, ref, t),
                            leading: CircleAvatar(
                              backgroundColor: color.withOpacity(0.2),
                              child: Icon(icon, color: color, size: 20),
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
                                      style: TextStyle(color: Colors.grey)),
                                  Text(
                                    '${t.installmentNumber}/${t.totalInstallments}x',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatCurrency(t.amount),
                                  style: TextStyle(
                                    color: t.isExpense
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
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