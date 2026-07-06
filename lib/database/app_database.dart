import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/installment_purchase.dart';
import 'daos/category_dao.dart';
import 'daos/transaction_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Categories, Transactions, InstallmentPurchases],
  daos: [CategoryDao, TransactionDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;
    

  @override
    MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _insertDefaultCategories();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(transactions, transactions.isRecurring);
        }
      },
  );

  Future<void> _insertDefaultCategories() async {
    final defaults = [
      CategoriesCompanion.insert(name: 'Alimentação', icon: 'food', color: '#FF6B6B'),
      CategoriesCompanion.insert(name: 'Saúde', icon: 'health', color: '#4ECDC4'),
      CategoriesCompanion.insert(name: 'Educação', icon: 'education', color: '#45B7D1'),
      CategoriesCompanion.insert(name: 'Lazer', icon: 'leisure', color: '#96CEB4'),
      CategoriesCompanion.insert(name: 'Transporte', icon: 'transport', color: '#FFEAA7'),
      CategoriesCompanion.insert(name: 'Moradia', icon: 'home', color: '#DDA0DD'),
      CategoriesCompanion.insert(name: 'Vestuário', icon: 'clothing', color: '#F0A500'),
      CategoriesCompanion.insert(name: 'Contas Fixas', icon: 'bills', color: '#E17055'),
      CategoriesCompanion.insert(name: 'Outros', icon: 'other', color: '#B0B0B0'),
      CategoriesCompanion.insert(name: 'Salário', icon: 'salary', color: '#00B894', isExpense: const Value(false)),
      CategoriesCompanion.insert(name: 'Presente', icon: 'gift', color: '#FDCB6E', isExpense: const Value(false)),
      CategoriesCompanion.insert(name: 'Cobrança', icon: 'charge', color: '#74B9FF', isExpense: const Value(false)),
      CategoriesCompanion.insert(name: 'Freelance', icon: 'freelance', color: '#A29BFE', isExpense: const Value(false)),
      CategoriesCompanion.insert(name: 'Investimento', icon: 'investment', color: '#55EFC4', isExpense: const Value(false)),
    ];

    for (final category in defaults) {
      await into(categories).insert(category);
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'finances.db'));
    return NativeDatabase.createInBackground(file);
  });
}