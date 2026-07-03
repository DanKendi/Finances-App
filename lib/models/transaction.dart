import 'package:drift/drift.dart';
import 'category.dart';

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isExpense => boolean().withDefault(const Constant(true))();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get paymentMethod => text().withDefault(const Constant('pix'))();
  IntColumn get installmentGroupId => integer().nullable()();
  IntColumn get installmentNumber => integer().nullable()();
  IntColumn get totalInstallments => integer().nullable()();
}