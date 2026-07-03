import 'package:drift/drift.dart';
import 'category.dart';

class InstallmentPurchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
  RealColumn get totalAmount => real()();
  IntColumn get totalInstallments => integer()();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get paymentMethod => text().withDefault(const Constant('cartão'))();
}