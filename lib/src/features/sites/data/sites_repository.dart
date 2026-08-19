import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/site_model.dart';

class SitesRepository {
  SitesRepository(this._database, this._uuid);

  final AppDatabase _database;
  final Uuid _uuid;

  Stream<List<SiteModel>> watchSites({
    String searchQuery = '',
    String? statusFilter,
  }) {
    final cleanQuery = searchQuery.trim();
    final cleanStatus = statusFilter?.trim() ?? '';

    final query = _database.select(_database.sites)
      ..where((site) {
        final isNotDeleted = site.deletedAt.isNull();
        final matchesStatus = cleanStatus.isEmpty
            ? const Constant(true)
            : site.status.equals(cleanStatus);
        final pattern = '%$cleanQuery%';
        final matchesSearch = cleanQuery.isEmpty
            ? const Constant(true)
            : (site.name.like(pattern) | site.roadInfo.like(pattern));
        return isNotDeleted & matchesStatus & matchesSearch;
      })
      ..orderBy([(site) => OrderingTerm.asc(site.name)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => SiteModel(
              id: row.id,
              name: row.name,
              roadInfo: row.roadInfo,
              latitude: row.latitude,
              longitude: row.longitude,
              status: row.status,
              notes: row.notes,
            ),
          )
          .toList(),
    );
  }

  Future<void> createSite({
    required String name,
    String? roadInfo,
    double? latitude,
    double? longitude,
    String status = 'active',
    String? notes,
  }) async {
    final now = DateTime.now().toUtc();
    final siteId = _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.sites)
          .insert(
            SitesCompanion.insert(
              id: siteId,
              name: name.trim(),
              roadInfo: Value(_cleanOptional(roadInfo)),
              latitude: Value(latitude),
              longitude: Value(longitude),
              status: Value(status.trim().isEmpty ? 'active' : status.trim()),
              notes: Value(_cleanOptional(notes)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueueChange('site', siteId, 'create', now);
    });
  }

  Future<void> updateSite({
    required String id,
    required String name,
    String? roadInfo,
    double? latitude,
    double? longitude,
    required String status,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.sites,
      )..where((site) => site.id.equals(id))).write(
        SitesCompanion(
          name: Value(name.trim()),
          roadInfo: Value(_cleanOptional(roadInfo)),
          latitude: Value(latitude),
          longitude: Value(longitude),
          status: Value(status.trim()),
          notes: Value(_cleanOptional(notes)),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _enqueueChange('site', id, 'update', now);
    });
  }

  Future<void> deleteSite(String id) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.sites,
      )..where((site) => site.id.equals(id))).write(
        SitesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pendingDelete.databaseValue),
        ),
      );
      await _enqueueChange('site', id, 'delete', now);
    });
  }

  Future<void> _enqueueChange(
    String entityType,
    String entityId,
    String operation,
    DateTime now,
  ) async {
    final existing =
        await (_database.select(_database.syncOutbox)..where(
              (entry) =>
                  entry.entityType.equals(entityType) &
                  entry.entityId.equals(entityId) &
                  entry.operation.equals(operation),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (_database.update(
        _database.syncOutbox,
      )..where((entry) => entry.id.equals(existing.id))).write(
        SyncOutboxCompanion(
          updatedAt: Value(now),
          attemptCount: const Value(0),
          nextAttemptAt: const Value(null),
          lastError: const Value(null),
        ),
      );
    } else {
      await _database
          .into(_database.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: _uuid.v4(),
              entityType: entityType,
              entityId: entityId,
              operation: operation,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
