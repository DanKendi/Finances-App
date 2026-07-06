import 'package:drift/drift.dart';
import '../app_database.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../models/installment_purchase.dart';

part 'transaction_dao.g.dart';

@DriftAccessor(tables: [Transactions, Categories, InstallmentPurchases])
class TransactionDao extends DatabaseAccessor<AppDatabase> with _$TransactionDaoMixin {
  TransactionDao(super.db);

  // Busca todas as transações ordenadas da mais recente para a mais antiga
  Stream<List<Transaction>> watchAllTransactions() {
    return (select(transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  // Busca transações de um mês/ano específico
  Stream<List<Transaction>> watchTransactionsByMonth(int month, int year) {
  final startDate = DateTime(year, month, 1);
  final endDate = DateTime(year, month + 1, 1);

  return (select(transactions)
        ..where((t) =>
            t.date.isBiggerOrEqualValue(startDate) &
            t.date.isSmallerThanValue(endDate))
        ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .watch();
}

  Future<int> insertTransaction(TransactionsCompanion transaction) =>
      into(transactions).insert(transaction);

  Future<bool> updateTransaction(Transaction transaction) =>
      update(transactions).replace(transaction);

  Future<int> deleteTransaction(Transaction transaction) =>
      delete(transactions).delete(transaction);

  // Insere compra parcelada gerando todas as parcelas automaticamente
  Future<void> insertInstallmentPurchase(InstallmentPurchasesCompanion purchase) async {
    final insertedId = await into(installmentPurchases).insert(purchase);
    final totalInstallments = purchase.totalInstallments.value;
    final totalAmount = purchase.totalAmount.value;
    final installmentValue = totalAmount / totalInstallments;
    final startDate = purchase.startDate.value;

    for (int i = 0; i < totalInstallments; i++) {
      final installmentDate = DateTime(
        startDate.year,
        startDate.month + i,
        startDate.day,
      );

      await into(transactions).insert(
        TransactionsCompanion.insert(
          description: '${purchase.description.value} (${i + 1}/$totalInstallments)',
          amount: installmentValue,
          date: installmentDate,
          categoryId: purchase.categoryId.value,
          paymentMethod: Value(purchase.paymentMethod.value),
          installmentGroupId: Value(insertedId),
          installmentNumber: Value(i + 1),
          totalInstallments: Value(totalInstallments),
        ),
      );
    }
  }

  Future<void> deleteTransactionById(int id) async {
    await (delete(transactions)..where((t) => t.id.equals(id))).go();
    }

    Future<void> updateTransactionById({
      required int id,
      required String description,
      required double amount,
      required DateTime date,
      required int categoryId,
      required String paymentMethod,
    }) async {
      await (update(transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          description: Value(description),
          amount: Value(amount),
          date: Value(date),
          categoryId: Value(categoryId),
          paymentMethod: Value(paymentMethod),
        ),
      );
    }

    Future<List<Transaction>> getAllTransactions() =>
      (select(transactions)..orderBy([(t) => OrderingTerm.desc(t.date)])).get();

    Future<Transaction?> getTransactionById(int id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

    Future<void> insertRecurringTransaction({
    required String description,
    required double amount,
    required DateTime startDate,
    required int months,
    required int categoryId,
    required String paymentMethod,
    required bool isExpense,
  }) async {
    final groupId = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < months; i++) {
      final date = DateTime(
        startDate.year,
        startDate.month + i,
        startDate.day,
      );

      await into(transactions).insert(
        TransactionsCompanion.insert(
          description: '$description (recorrente ${i + 1}/$months)',
          amount: amount,
          date: date,
          isExpense: Value(isExpense),
          categoryId: categoryId,
          paymentMethod: Value(paymentMethod),
          installmentGroupId: Value(groupId),
          installmentNumber: Value(i + 1),
          totalInstallments: Value(months),
          isRecurring: const Value(true),
        ),
      );
    }
  }

  // Atualiza apenas esta transação recorrente
  Future<void> updateSingleRecurring({
    required int id,
    required String description,
    required double amount,
    required DateTime date,
    required int categoryId,
    required String paymentMethod,
  }) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        description: Value(description),
        amount: Value(amount),
        date: Value(date),
        categoryId: Value(categoryId),
        paymentMethod: Value(paymentMethod),
      ),
    );
  }

  // Atualiza esta e todas as subsequentes do mesmo grupo
  Future<void> updateSubsequentRecurring({
    required int groupId,
    required int fromInstallmentNumber,
    required String baseDescription,
    required double amount,
    required int categoryId,
    required String paymentMethod,
  }) async {
    // Busca todas as subsequentes
    final subsequent = await (select(transactions)
          ..where((t) =>
              t.installmentGroupId.equals(groupId) &
              t.installmentNumber.isBiggerOrEqualValue(fromInstallmentNumber))
          ..orderBy([(t) => OrderingTerm.asc(t.installmentNumber)]))
        .get();

    // Extrai o padrão da descrição (remove o sufixo recorrente)
    final totalInstallments = subsequent.isNotEmpty
        ? subsequent.first.totalInstallments ?? subsequent.length
        : subsequent.length;

    for (final t in subsequent) {
      final newDescription =
          '${baseDescription} (recorrente ${t.installmentNumber}/$totalInstallments)';
      await (update(transactions)..where((t2) => t2.id.equals(t.id))).write(
        TransactionsCompanion(
          description: Value(newDescription),
          amount: Value(amount),
          categoryId: Value(categoryId),
          paymentMethod: Value(paymentMethod),
        ),
      );
    }
  }
}