// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wish_dao.dart';

// ignore_for_file: type=lint
mixin _$WishDaoMixin on DatabaseAccessor<AppDatabase> {
  $WishItemsTable get wishItems => attachedDatabase.wishItems;
  WishDaoManager get managers => WishDaoManager(this);
}

class WishDaoManager {
  final _$WishDaoMixin _db;
  WishDaoManager(this._db);
  $$WishItemsTableTableManager get wishItems =>
      $$WishItemsTableTableManager(_db.attachedDatabase, _db.wishItems);
}
