import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/progress_model.dart';

class ProgressRepository {
  ProgressRepository(this._db, this._uuid);

  final AppDatabase _db;
  final Uuid _uuid;

  // ---------------------------------------------------------------------------
  // Watch / Query
  // ---------------------------------------------------------------------------

  Stream<List<ProgressModel>> watchProgressUpdates({
    String searchQuery = '',
    String? statusFilter,
    String? schemeIdFilter,
  }) {
    final cleanQuery = searchQuery.trim();
    final cleanStatus = statusFilter?.trim() ?? '';
    final cleanScheme = schemeIdFilter?.trim() ?? '';

    const sql = '''
      SELECT
        p.id,
        p.scheme_id,
        sc.name   AS scheme_name,
        p.site_id,
        st.name   AS site_name,
        p.status,
        p.progress_percentage,
        p.date,
        p.incomplete_reason,
        p.result,
        p.remarks
      FROM progress_updates p
      JOIN schemes sc ON sc.id = p.scheme_id AND sc.deleted_at IS NULL
      LEFT JOIN sites st ON st.id = p.site_id AND st.deleted_at IS NULL
      WHERE p.deleted_at IS NULL
        AND (? = '' OR p.scheme_id = ?)
        AND (? = '' OR p.status = ?)
        AND (
          ? = ''
          OR LOWER(sc.name)       LIKE LOWER(?)
          OR LOWER(p.result)      LIKE LOWER(?)
          OR LOWER(p.remarks)     LIKE LOWER(?)
        )
      ORDER BY p.date DESC, p.created_at DESC
    ''';
    final pattern = '%$cleanQuery%';

    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withString(cleanScheme),
            Variable.withString(cleanScheme),
            Variable.withString(cleanStatus),
            Variable.withString(cleanStatus),
            Variable.withString(cleanQuery),
            Variable.withString(pattern),
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {_db.progressUpdates, _db.schemes, _db.sites},
        )
        .watch()
        .map((rows) => rows.map(_progressFromRow).toList());
  }

  Stream<List<ProgressModel>> watchProgressByScheme(String schemeId) =>
      watchProgressUpdates(schemeIdFilter: schemeId);

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<String> createProgress({
    required String schemeId,
    String? siteId,
    required String status,
    required double progressPercentage,
    required DateTime date,
    String? incompleteReason,
    String? result,
    String? remarks,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      await _db
          .into(_db.progressUpdates)
          .insert(
            ProgressUpdatesCompanion.insert(
              id: id,
              schemeId: schemeId,
              siteId: Value(_cleanOptional(siteId)),
              status: status,
              progressPercentage: Value(progressPercentage.clamp(0.0, 100.0)),
              date: date.toUtc(),
              incompleteReason: Value(_cleanOptional(incompleteReason)),
              result: Value(_cleanOptional(result)),
              remarks: Value(_cleanOptional(remarks)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueueChange('progress_update', id, 'create', now);
      await _updateSchemeLatestStatus(schemeId, now);
    });

    return id;
  }

  Future<void> updateProgress({
    required String id,
    required String schemeId,
    String? siteId,
    required String status,
    required double progressPercentage,
    required DateTime date,
    String? incompleteReason,
    String? result,
    String? remarks,
  }) async {
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      await (_db.update(
        _db.progressUpdates,
      )..where((t) => t.id.equals(id))).write(
        ProgressUpdatesCompanion(
          siteId: Value(_cleanOptional(siteId)),
          status: Value(status),
          progressPercentage: Value(progressPercentage.clamp(0.0, 100.0)),
          date: Value(date.toUtc()),
          incompleteReason: Value(_cleanOptional(incompleteReason)),
          result: Value(_cleanOptional(result)),
          remarks: Value(_cleanOptional(remarks)),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _enqueueChange('progress_update', id, 'update', now);
      await _updateSchemeLatestStatus(schemeId, now);
    });
  }

  Future<void> deleteProgress(String id) async {
    final now = DateTime.now().toUtc();

    final existing = await (_db.select(
      _db.progressUpdates,
    )..where((t) => t.id.equals(id))).getSingle();

    await _db.transaction(() async {
      await (_db.update(
        _db.progressUpdates,
      )..where((t) => t.id.equals(id))).write(
        ProgressUpdatesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pendingDelete.databaseValue),
        ),
      );
      await _enqueueChange('progress_update', id, 'delete', now);
      await _updateSchemeLatestStatus(existing.schemeId, now);
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// After any progress mutation, sync the parent scheme's status/percentage
  /// to the latest non-deleted progress update for that scheme.
  Future<void> _updateSchemeLatestStatus(String schemeId, DateTime now) async {
    const sql = '''
      SELECT status, progress_percentage, incomplete_reason, result
      FROM progress_updates
      WHERE scheme_id = ? AND deleted_at IS NULL
      ORDER BY date DESC, created_at DESC
      LIMIT 1
    ''';

    final rows = await _db
        .customSelect(sql, variables: [Variable.withString(schemeId)])
        .get();

    if (rows.isNotEmpty) {
      final row = rows.first;
      await (_db.update(
        _db.schemes,
      )..where((s) => s.id.equals(schemeId))).write(
        SchemesCompanion(
          status: Value(row.read<String>('status')),
          progressPercentage: Value(row.read<double>('progress_percentage')),
          incompleteReason: Value(
            row.readNullable<String>('incomplete_reason'),
          ),
          result: Value(row.readNullable<String>('result')),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
    } else {
      await (_db.update(
        _db.schemes,
      )..where((s) => s.id.equals(schemeId))).write(
        SchemesCompanion(
          status: const Value('initial'),
          progressPercentage: const Value(0.0),
          incompleteReason: const Value(null),
          result: const Value(null),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
    }
    await _enqueueChange('scheme', schemeId, 'update', now);
  }

  Future<void> _enqueueChange(
    String entityType,
    String entityId,
    String operation,
    DateTime now,
  ) async {
    final existing =
        await (_db.select(_db.syncOutbox)..where(
              (e) =>
                  e.entityType.equals(entityType) &
                  e.entityId.equals(entityId) &
                  e.operation.equals(operation),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (_db.update(
        _db.syncOutbox,
      )..where((e) => e.id.equals(existing.id))).write(
        SyncOutboxCompanion(
          updatedAt: Value(now),
          attemptCount: const Value(0),
          nextAttemptAt: const Value(null),
          lastError: const Value(null),
        ),
      );
    } else {
      await _db
          .into(_db.syncOutbox)
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

  ProgressModel _progressFromRow(QueryRow row) {
    return ProgressModel(
      id: row.read<String>('id'),
      schemeId: row.read<String>('scheme_id'),
      schemeName: row.read<String>('scheme_name'),
      siteId: row.readNullable<String>('site_id'),
      siteName: row.readNullable<String>('site_name'),
      status: row.read<String>('status'),
      progressPercentage: row.read<double>('progress_percentage'),
      date: row.read<DateTime>('date'),
      incompleteReason: row.readNullable<String>('incomplete_reason'),
      result: row.readNullable<String>('result'),
      remarks: row.readNullable<String>('remarks'),
    );
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
