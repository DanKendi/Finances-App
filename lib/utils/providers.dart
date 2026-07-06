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