import 'package:drift/drift.dart';

import 'syncable_table.dart';

class Sites extends Table with SyncableTable {
  TextColumn get name => text()();
  TextColumn get roadInfo => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
