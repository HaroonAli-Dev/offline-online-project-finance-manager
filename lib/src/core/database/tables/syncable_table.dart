import 'package:drift/drift.dart';

/// Common columns for every business record that will synchronize with Supabase.
mixin SyncableTable on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get remoteUpdatedAt => dateTime().nullable()();
}
