import 'package:drift/drift.dart';

class Roles extends Table {
  TextColumn get code => text()();
  TextColumn get displayName => text()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {code};
}
