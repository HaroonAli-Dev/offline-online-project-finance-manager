import 'package:drift/drift.dart';

import 'people.dart';
import 'schemes.dart';
import 'sites.dart';
import 'syncable_table.dart';

class Expenses extends Table with SyncableTable {
  TextColumn get expenseCode => text()();
  DateTimeColumn get expenseDate => dateTime()();
  TextColumn get category => text()();
  IntColumn get amount => integer().withDefault(
    const Constant(0),
  )(); // amount in paisa (1 PKR = 100 paisa)
  TextColumn get purpose => text()();
  TextColumn get siteId => text().nullable().references(Sites, #id)();
  TextColumn get schemeId => text().nullable().references(Schemes, #id)();
  TextColumn get personId => text().nullable().references(People, #id)();
  TextColumn get remarks => text().nullable()();
  TextColumn get attachmentPath => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
