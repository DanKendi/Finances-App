import 'package:drift/drift.dart';
import 'category.dart';

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  RealColumn get value => real()(); // valor nominal
  BoolColumn get isPercentage => boolean().withDefault(const Constant(false))();
  RealColumn get percentage => real().nullable()(); // % da renda
}