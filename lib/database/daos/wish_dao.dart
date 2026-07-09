import 'package:drift/drift.dart';
import '../app_database.dart';
import '../../models/wish_item.dart';

part 'wish_dao.g.dart';

@DriftAccessor(tables: [WishItems])
class WishDao extends DatabaseAccessor<AppDatabase> with _$WishDaoMixin {
  WishDao(super.db);

  Stream<List<WishItem>> watchAllWishItems() =>
      (select(wishItems)
        ..orderBy([
          (w) => OrderingTerm.desc(w.priority),
          (w) => OrderingTerm.asc(w.isAchieved),
          (w) => OrderingTerm.asc(w.createdAt),
        ]))
          .watch();

  Future<int> insertWishItem(WishItemsCompanion item) =>
      into(wishItems).insert(item);

  Future<bool> updateWishItem(WishItem item) =>
      update(wishItems).replace(item);

  Future<int> deleteWishItem(WishItem item) =>
      delete(wishItems).delete(item);
}