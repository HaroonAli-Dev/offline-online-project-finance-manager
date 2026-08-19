import 'package:drift/drift.dart';

import 'schemes.dart';
import 'sites.dart';
import 'syncable_table.dart';

/// A historical progress update record for a Scheme (and optionally Site).
///
/// Progress updates track the timeline of a project's completion status.
class ProgressUpdates extends Table with SyncableTable {
  /// Foreign key to the parent scheme.
  TextColumn get schemeId => text().references(Schemes, #id)();

  /// Optional foreign key to a specific site within the scheme.
  TextColumn get siteId => text().nullable().references(Sites, #id)();

  /// 'initial', 'working', 'in_progress', 'completed', 'incomplete'
  TextColumn get status => text()();

  /// Completion percentage (0.0 - 100.0)
  RealColumn get progressPercentage =>
      real().withDefault(const Constant(0.0))();

  /// Date the progress was recorded.
  DateTimeColumn get date => dateTime()();

  /// Required if status == 'incomplete'
  TextColumn get incompleteReason => text().nullable()();

  /// Short summary of what was achieved (e.g. "Poured foundation")
  TextColumn get result => text().nullable()();

  /// Optional free-text remarks.
  TextColumn get remarks => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
