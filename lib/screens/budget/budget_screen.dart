import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../database/app_database.dart';
import '../../utils/providers.dart';
import '../../utils/formatters.dart';
import '../../utils/constants.dart';
import '../../main.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final expensesByCategory = ref.watch(expensesByCategoryProvider);
    final monthlyIncome = ref.watch(monthlyIncomeBaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metas'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBudgetDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nova meta'),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          //final expenseCats = categories.where((c) => c.isExpense).toList();
          final categoryMap = {for (final c in categories) c.id: c};

          return budgetsAsync.when(
            data: (budgets) {
              if (budgets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.track_changes_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Nenhuma meta definida ainda.',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            _showAddBudgetDialog(context, ref),
                        child: const Text('Criar primeira meta'),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // Card de renda base
                  monthlyIncome.when(
                    data: (income) => _IncomeBaseCard(income: income),
                    loading: () => const SizedBox(),
                    error: (e, _) => const SizedBox(),
                  ),
                  const SizedBox(height: 16),
                  Text('Metas do mês',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),

                  ...budgets.map((budget) {
                    final category = categoryMap[budget.categoryId];
                    if (category == null) return const SizedBox();

                    final color = hexToColor(category.color);
                    final icon =
                        categoryIcons[category.icon] ?? Icons.category;
                    final spent =
                        expensesByCategory.whenOrNull(
                            data: (map) => map[budget.categoryId]) ??
                            0.0;

                    final budgetValue = budget.isPercentage
                        ? monthlyIncome.whenOrNull(
                              data: (income) =>
                                  income * (budget.percentage ?? 0) / 100,
                            ) ??
                            budget.value
                        : budget.value;

                    final progress = budgetValue > 0
                        ? (spent / budgetValue).clamp(0.0, 1.0)
                        : 0.0;
                    final isOver = spent > budgetValue;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: color.withOpacity(0.2),
                                  child:
                                      Icon(icon, color: color, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(category.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                ),
                                IconButton(
                                  onPressed: () => _deleteBudget(
                                      context, ref, budget),
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: Colors.grey),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Barra de progresso
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor:
                                    Colors.grey.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isOver
                                      ? Colors.redAccent
                                      : progress > 0.8
                                          ? Colors.orangeAccent
                                          : Colors.greenAccent.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatCurrency(spent),
                                  style: TextStyle(
                                    color: isOver
                                        ? Colors.redAccent
                                        : Colors.greenAccent.shade400,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (budget.isPercentage)
                                      Text(
                                        '${budget.percentage?.toStringAsFixed(0)}% · ',
                                        style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12),
                                      ),
                                    Text(
                                      formatCurrency(budgetValue),
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (isOver)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Excedeu ${formatCurrency(spent - budgetValue)}',
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
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

  Future<void> _showAddBudgetDialog(
      BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddBudgetSheet(),
    );
  }

  Future<void> _deleteBudget(
      BuildContext context, WidgetRef ref, Budget budget) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover meta'),
        content: const Text('Deseja remover esta meta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(databaseProvider);
      await db.budgetDao.deleteBudget(budget);
    }
  }
}

class _IncomeBaseCard extends StatelessWidget {
  final double income;
  const _IncomeBaseCard({required this.income});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.greenAccent.shade700.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.greenAccent.shade700.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet,
              color: Colors.greenAccent.shade400),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Renda do mês',
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 12)),
              Text(
                formatCurrency(income),
                style: TextStyle(
                  color: Colors.greenAccent.shade400,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddBudgetSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends ConsumerState<_AddBudgetSheet> {
  final _valueController = TextEditingController();
  int? _selectedCategoryId;
  bool _isPercentage = false;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedCategoryId == null || _valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Preencha todos os campos')),
      );
      return;
    }

    final value =
        double.tryParse(_valueController.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor inválido')),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    await db.budgetDao.upsertBudget(
      BudgetsCompanion.insert(
        categoryId: _selectedCategoryId!,
        value: value,
        isPercentage: Value(_isPercentage),
        percentage: Value(_isPercentage ? value : null),
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Nova meta',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          // Tipo de valor
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPercentage = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isPercentage
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text('Valor (R\$)',
                            style: TextStyle(
                              color: !_isPercentage
                                  ? Colors.white
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPercentage = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isPercentage
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text('Percentual (%)',
                            style: TextStyle(
                              color: _isPercentage
                                  ? Colors.white
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Valor
          TextFormField(
            controller: _valueController,
            decoration: InputDecoration(
              labelText: _isPercentage ? 'Percentual (%)' : 'Valor (R\$)',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(
                  _isPercentage ? Icons.percent : Icons.attach_money),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),

          // Categoria
          categoriesAsync.when(
            data: (cats) {
              final expenseCats =
                  cats.where((c) => c.isExpense).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Categoria',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: expenseCats.map((cat) {
                      final isSelected = _selectedCategoryId == cat.id;
                      final color = hexToColor(cat.color);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(cat.name),
                        avatar: Icon(
                          categoryIcons[cat.icon] ?? Icons.category,
                          size: 16,
                          color: isSelected ? Colors.white : color,
                        ),
                        selectedColor: color,
                        onSelected: (_) => setState(
                            () => _selectedCategoryId = cat.id),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Erro: $e'),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Salvar meta'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }
}