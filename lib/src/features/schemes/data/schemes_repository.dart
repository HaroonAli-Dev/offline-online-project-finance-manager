import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/scheme_model.dart';

class SchemesRepository {
  SchemesRepository(this._database, this._uuid);

  final AppDatabase _database;
  final Uuid _uuid;

  Stream<List<SchemeModel>> watchSchemes({
    String searchQuery = '',
    String? siteFilter,
    String? engineerFilter,
    String? statusFilter,
  }) {
    final cleanQuery = searchQuery.trim();
    final cleanSite = siteFilter?.trim() ?? '';
    final cleanEngineer = engineerFilter?.trim() ?? '';
    final cleanStatus = statusFilter?.trim() ?? '';

    const querySql = '''
      SELECT
        s.id,
        s.scheme_code,
        s.name,
        s.site_id,
        st.name AS site_name,
        s.budget,
        s.engineer_id,
        p.full_name AS engineer_name,
        s.start_date,
        s.end_date,
        s.status,
        s.progress_percentage,
        s.incomplete_reason,
        s.result,
        s.description
      FROM schemes s
      LEFT JOIN sites st ON st.id = s.site_id AND st.deleted_at IS NULL
      LEFT JOIN people p ON p.id = s.engineer_id AND p.deleted_at IS NULL
      WHERE s.deleted_at IS NULL
        AND (? = '' OR s.site_id = ?)
        AND (? = '' OR s.engineer_id = ?)
        AND (? = '' OR s.status = ?)
        AND (
          ? = ''
          OR LOWER(s.name) LIKE LOWER(?)
          OR LOWER(s.scheme_code) LIKE LOWER(?)
        )
      ORDER BY s.scheme_code COLLATE NOCASE
    ''';
    final pattern = '%$cleanQuery%';

    return _database
        .customSelect(
          querySql,
          variables: [
            Variable.withString(cleanSite),
            Variable.withString(cleanSite),
            Variable.withString(cleanEngineer),
            Variable.withString(cleanEngineer),
            Variable.withString(cleanStatus),
            Variable.withString(cleanStatus),
            Variable.withString(cleanQuery),
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {_database.schemes, _database.sites, _database.people},
        )
        .watch()
        .map((rows) => rows.map(_schemeFromRow).toList());
  }

  Future<void> createScheme({
    required String schemeCode,
    required String name,
    String? siteId,
    required double budget,
    String? engineerId,
    DateTime? startDate,
    DateTime? endDate,
    String status = 'initial',
    double progressPercentage = 0.0,
    String? incompleteReason,
    String? result,
    String? description,
  }) async {
    final now = DateTime.now().toUtc();
    final schemeId = _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.schemes)
          .insert(
            SchemesCompanion.insert(
              id: schemeId,
              schemeCode: schemeCode.trim(),
              name: name.trim(),
              siteId: Value(_cleanOptional(siteId)),
              budget: Value(budget < 0 ? 0 : (budget * 100).round()),
              engineerId: Value(_cleanOptional(engineerId)),
              startDate: Value(startDate?.toUtc()),
              endDate: Value(endDate?.toUtc()),
              status: Value(status.trim().isEmpty ? 'initial' : status.trim()),
              progressPercentage: Value(progressPercentage.clamp(0.0, 100.0)),
              incompleteReason: Value(_cleanOptional(incompleteReason)),
              result: Value(_cleanOptional(result)),
              description: Value(_cleanOptional(description)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueueChange('scheme', schemeId, 'create', now);
    });
  }

  Future<void> updateScheme({
    required String id,
    required String schemeCode,
    required String name,
    String? siteId,
    required double budget,
    String? engineerId,
    DateTime? startDate,
    DateTime? endDate,
    required String status,
    required double progressPercentage,
    String? incompleteReason,
    String? result,
    String? description,
  }) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.schemes,
      )..where((scheme) => scheme.id.equals(id))).write(
        SchemesCompanion(
          schemeCode: Value(schemeCode.trim()),
          name: Value(name.trim()),
          siteId: Value(_cleanOptional(siteId)),
          budget: Value(budget < 0 ? 0 : (budget * 100).round()),
          engineerId: Value(_cleanOptional(engineerId)),
          startDate: Value(startDate?.toUtc()),
          endDate: Value(endDate?.toUtc()),
          status: Value(status.trim()),
          progressPercentage: Value(progressPercentage.clamp(0.0, 100.0)),
          incompleteReason: Value(_cleanOptional(incompleteReason)),
          result: Value(_cleanOptional(result)),
          description: Value(_cleanOptional(description)),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _enqueueChange('scheme', id, 'update', now);
    });
  }

  Future<void> deleteScheme(String id) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.schemes,
      )..where((scheme) => scheme.id.equals(id))).write(
        SchemesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pendingDelete.databaseValue),
        ),
      );
      await _enqueueChange('scheme', id, 'delete', now);
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

  SchemeModel _schemeFromRow(QueryRow row) {
    return SchemeModel(
      id: row.read<String>('id'),
      schemeCode: row.read<String>('scheme_code'),
      name: row.read<String>('name'),
      siteId: row.readNullable<String>('site_id'),
      siteName: row.readNullable<String>('site_name'),
      budget: (row.read<int>('budget')) / 100.0,
      engineerId: row.readNullable<String>('engineer_id'),
      engineerName: row.readNullable<String>('engineer_name'),
      startDate: row.readNullable<DateTime>('start_date'),
      endDate: row.readNullable<DateTime>('end_date'),
      status: row.read<String>('status'),
      progressPercentage: row.read<double>('progress_percentage'),
      incompleteReason: row.readNullable<String>('incomplete_reason'),
      result: row.readNullable<String>('result'),
      description: row.readNullable<String>('description'),
    );
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
