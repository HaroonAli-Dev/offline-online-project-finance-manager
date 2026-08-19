import 'package:drift/drift.dart';

import 'people.dart';
import 'roles.dart';

class PersonRoles extends Table {
  TextColumn get personId => text().references(People, #id)();
  TextColumn get roleCode => text().references(Roles, #code)();

  @override
  Set<Column<Object>> get primaryKey => {personId, roleCode};
}
