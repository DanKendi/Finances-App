import 'package:drift/drift.dart';

class WishItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  RealColumn get targetValue => real()();
  RealColumn get savedValue => real().withDefault(const Constant(0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(1))(); // 1=baixa, 2=média, 3=alta
  BoolColumn get isAchieved => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}