import 'package:drift/drift.dart';

import 'people.dart';
import 'sites.dart';
import 'syncable_table.dart';

class Schemes extends Table with SyncableTable {
  TextColumn get schemeCode => text()();
  TextColumn get name => text()();
  TextColumn get siteId => text().nullable().references(Sites, #id)();
  IntColumn get budget =>
      integer().withDefault(const Constant(0))(); // budget in paisa
  TextColumn get engineerId => text().nullable().references(People, #id)();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('initial'))();
  RealColumn get progressPercentage =>
      real().withDefault(const Constant(0.0))();
  TextColumn get incompleteReason => text().nullable()();
  TextColumn get result => text().nullable()();
  TextColumn get description => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
