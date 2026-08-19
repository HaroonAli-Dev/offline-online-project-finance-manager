import 'package:drift/drift.dart';

import 'schemes.dart';
import 'sites.dart';
import 'syncable_table.dart';

/// A reminder record with an optional due date/time and optional links to
/// a Scheme or Site.
///
/// Completion is tracked via [isDone] and [doneAt].
/// Priority: 'low', 'medium', 'high'.
class Reminders extends Table with SyncableTable {
  /// Short title of the reminder (required).
  TextColumn get title => text()();

  /// Optional longer description.
  TextColumn get description => text().nullable()();

  /// When the reminder is due (UTC). Nullable — some reminders have no deadline.
  DateTimeColumn get dueAt => dateTime().nullable()();

  /// Priority: 'low', 'medium', 'high'.
  TextColumn get priority => text().withDefault(const Constant('medium'))();

  /// Whether the reminder has been completed.
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();

  /// When the reminder was marked done (UTC). Null if not yet done.
  DateTimeColumn get doneAt => dateTime().nullable()();

  /// Optional link to a scheme.
  TextColumn get schemeId => text().nullable().references(Schemes, #id)();

  /// Optional link to a site.
  TextColumn get siteId => text().nullable().references(Sites, #id)();

  /// Optional free-text remarks.
  TextColumn get remarks => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
