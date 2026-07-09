import 'package:drift/drift.dart';
import '../app_database.dart';
import '../../models/budget.dart';

part 'budget_dao.g.dart';

@DriftAccessor(tables: [Budgets])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);

  Stream<List<Budget>> watchAllBudgets() => select(budgets).watch();

  Future<List<Budget>> getAllBudgets() => select(budgets).get();

  Future<Budget?> getBudgetByCategoryId(int categoryId) =>
      (select(budgets)..where((b) => b.categoryId.equals(categoryId)))
          .getSingleOrNull();

  Future<int> insertBudget(BudgetsCompanion budget) =>
      into(budgets).insert(budget);

  Future<void> upsertBudget(BudgetsCompanion budget) =>
      into(budgets).insertOnConflictUpdate(budget);

  Future<int> deleteBudget(Budget budget) =>
      delete(budgets).delete(budget);

  Future<void> deleteBudgetByCategoryId(int categoryId) =>
      (delete(budgets)..where((b) => b.categoryId.equals(categoryId))).go();
}