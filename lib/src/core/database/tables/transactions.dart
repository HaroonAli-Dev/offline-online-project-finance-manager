import 'package:drift/drift.dart';

import 'people.dart';
import 'schemes.dart';
import 'sites.dart';
import 'syncable_table.dart';

class Transactions extends Table with SyncableTable {
  TextColumn get transactionCode => text()();
  DateTimeColumn get transactionDate => dateTime()();
  TextColumn get type => text()(); // 'received' or 'paid'
  TextColumn get personId => text().nullable().references(People, #id)();
  IntColumn get amount =>
      integer().withDefault(const Constant(0))(); // amount in paisa
  RealColumn get quantity => real().nullable()();
  TextColumn get purpose => text()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get referenceNumber => text().nullable()();
  TextColumn get remarks => text().nullable()();
  TextColumn get schemeId => text().nullable().references(Schemes, #id)();
  TextColumn get siteId => text().nullable().references(Sites, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
