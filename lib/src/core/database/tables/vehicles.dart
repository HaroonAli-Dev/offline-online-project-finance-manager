import 'package:drift/drift.dart';

import 'people.dart';
import 'sites.dart';
import 'syncable_table.dart';

class Vehicles extends Table with SyncableTable {
  TextColumn get vehicleNumber => text()();
  TextColumn get makeModel => text()();
  TextColumn get vehicleType => text().withDefault(const Constant('truck'))();
  TextColumn get assignedSiteId => text().nullable().references(Sites, #id)();
  TextColumn get assignedDriverId =>
      text().nullable().references(People, #id)();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get remarks => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
