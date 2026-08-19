import 'package:drift/drift.dart';

import 'people.dart';
import 'sites.dart';
import 'syncable_table.dart';
import 'vehicles.dart';

class VehicleLogs extends Table with SyncableTable {
  TextColumn get vehicleId => text().references(Vehicles, #id)();
  DateTimeColumn get logDate => dateTime()();
  TextColumn get logType => text()(); // fuel, maintenance, trip, expenditure
  IntColumn get amount =>
      integer().withDefault(const Constant(0))(); // amount in paisa
  RealColumn get quantityLiters => real().nullable()();
  TextColumn get driverId => text().nullable().references(People, #id)();
  TextColumn get siteId => text().nullable().references(Sites, #id)();
  TextColumn get description => text()();
  RealColumn get odometerReading => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
