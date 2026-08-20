import 'package:drift/drift.dart';

import 'reminders.dart';
import 'syncable_table.dart';

/// Polymorphic links that allow a reminder to relate to any supported entity,
/// while still preserving the existing scheme/site columns for compatibility.
class ReminderEntityLinks extends Table with SyncableTable {
  TextColumn get reminderId => text().references(Reminders, #id)();

  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {reminderId, entityType, entityId},
  ];
}
