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
          ..where((t) => t.date.isBetweenValues(startDate, endDate))
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
}