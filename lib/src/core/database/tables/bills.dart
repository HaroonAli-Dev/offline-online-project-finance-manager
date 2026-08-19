import 'package:drift/drift.dart';

import 'schemes.dart';
import 'syncable_table.dart';

/// A construction/project billing record attached to a Scheme.
///
/// Bill sequence codes: initial, first, second, third, fourth, final, other.
/// Amount is stored in paisa (1 PKR = 100 paisa) as a non-negative integer.
class Bills extends Table with SyncableTable {
  /// Foreign key to the parent scheme.
  TextColumn get schemeId => text().references(Schemes, #id)();

  /// Internal bill sequence code: 'initial', 'first', 'second', 'third',
  /// 'fourth', 'final', 'other'. Extensible string — not hard-coded enum.
  TextColumn get billType => text()();

  /// Optional reference number used by the client (e.g. "Bill No. 3/2026").
  TextColumn get billNumber => text().nullable()();

  /// Date the bill was raised.
  DateTimeColumn get billDate => dateTime()();

  /// Billed amount in paisa (1 PKR = 100 paisa). Must be >= 0.
  IntColumn get amount => integer().withDefault(const Constant(0))(); // paisa

  /// Lifecycle status: 'draft', 'submitted', 'approved', 'paid', 'rejected'.
  TextColumn get status => text().withDefault(const Constant('draft'))();

  /// Optional free-text remarks.
  TextColumn get remarks => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
