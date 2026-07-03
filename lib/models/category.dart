import 'package:drift/drift.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get icon => text()(); // nome do ícone, ex: 'health', 'education'
  TextColumn get color => text()(); // cor em hex, ex: '#FF5733'
  BoolColumn get isExpense => boolean().withDefault(const Constant(true))();
}