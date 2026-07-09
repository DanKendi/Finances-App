import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../main.dart';

// Provider do mês/ano selecionado — começa no mês atual
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// Provider das transações do mês selecionado
final transactionsByMonthProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  return db.transactionDao.watchTransactionsByMonth(
    selectedMonth.month,
    selectedMonth.year,
  );
});

// Provider de todas as transações (para o histórico completo)
final allTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.transactionDao.watchAllTransactions();
});

// Provider das categorias
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.categoryDao.watchAllCategories();
});

// Provider do total de gastos do mês
final monthlyTotalProvider = Provider<AsyncValue<double>>((ref) {
  final transactions = ref.watch(transactionsByMonthProvider);
  return transactions.whenData(
    (list) => list
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount),
  );
});

// Provider dos gastos agrupados por categoria (para o gráfico de rosca)
final expensesByCategoryProvider = Provider<AsyncValue<Map<int, double>>>((ref) {
  final transactions = ref.watch(transactionsByMonthProvider);
  return transactions.whenData((list) {
    final map = <int, double>{};
    for (final t in list.where((t) => t.isExpense)) {
      map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amount;
    }
    return map;
  });
});

// Receita total do mês selecionado
final monthlyIncomeProvider = Provider<AsyncValue<double>>((ref) {
  final transactions = ref.watch(transactionsByMonthProvider);
  return transactions.whenData(
    (list) => list
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount),
  );
});

// Saldo do mês selecionado (receitas - gastos)
final monthlyBalanceProvider = Provider<AsyncValue<double>>((ref) {
  final transactions = ref.watch(transactionsByMonthProvider);
  return transactions.whenData((list) {
    double balance = 0;
    for (final t in list) {
      balance += t.isExpense ? -t.amount : t.amount;
    }
    return balance;
  });
});

// Dados dos últimos 6 meses para o comparativo
final monthlyComparisonProvider = StreamProvider<List<MonthSummary>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.transactionDao.watchAllTransactions().map((transactions) {
    final now = DateTime.now();
    final summaries = <MonthSummary>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(now.year, now.month - i + 1, 1);

      final monthTransactions = transactions.where((t) =>
          t.date.isAfter(month.subtract(const Duration(seconds: 1))) &&
          t.date.isBefore(nextMonth));

      final expenses = monthTransactions
          .where((t) => t.isExpense)
          .fold(0.0, (sum, t) => sum + t.amount);

      final income = monthTransactions
          .where((t) => !t.isExpense)
          .fold(0.0, (sum, t) => sum + t.amount);

      summaries.add(MonthSummary(
        month: month,
        expenses: expenses,
        income: income,
      ));
    }

    return summaries;
  });
});

class MonthSummary {
  final DateTime month;
  final double expenses;
  final double income;

  MonthSummary({
    required this.month,
    required this.expenses,
    required this.income,
  });
}

// Providers de metas
final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.budgetDao.watchAllBudgets();
});

// Renda total do mês selecionado (base para calcular percentuais)
final monthlyIncomeBaseProvider = Provider<AsyncValue<double>>((ref) {
  final transactions = ref.watch(transactionsByMonthProvider);
  return transactions.whenData(
    (list) => list
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount),
  );
});

// Providers de desejos
final wishItemsProvider = StreamProvider<List<WishItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.wishDao.watchAllWishItems();
});