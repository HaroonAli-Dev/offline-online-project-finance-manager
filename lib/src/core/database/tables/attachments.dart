import 'package:drift/drift.dart';

import 'syncable_table.dart';

/// Stores metadata for locally-saved files (photos, documents, receipts).
///
/// Actual file bytes live on the device filesystem (or browser storage on Web).
/// This table records the path/reference and descriptive metadata only.
///
/// Linked to any entity via [entityType] + [entityId] (same polymorphic
/// pattern used by SyncOutbox).
class Attachments extends Table with SyncableTable {
  /// The type of the owning record, e.g. 'scheme', 'site', 'bill',
  /// 'expense', 'progress_update'.
  TextColumn get entityType => text()();

  /// The UUID of the owning record.
  TextColumn get entityId => text()();

  /// Local filesystem path (Windows/Android) or a descriptive label (Web).
  /// Nullable because on Web we may only have a name, not a persistent path.
  TextColumn get filePath => text().nullable()();

  /// Original filename including extension, e.g. "site_photo_01.jpg".
  TextColumn get fileName => text()();

  /// MIME type, e.g. 'image/jpeg', 'application/pdf'. Nullable if unknown.
  TextColumn get mimeType => text().nullable()();

  /// Broad category: 'photo', 'document', 'receipt', 'other'.
  TextColumn get category => text().withDefault(const Constant('other'))();

  /// Optional human-readable description.
  TextColumn get description => text().nullable()();

  /// When the file was captured / created (UTC). Defaults to insert time.
  DateTimeColumn get capturedAt => dateTime()();

  /// Optional GPS latitude (decimal degrees).
  RealColumn get latitude => real().nullable()();

  /// Optional GPS longitude (decimal degrees).
  RealColumn get longitude => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
