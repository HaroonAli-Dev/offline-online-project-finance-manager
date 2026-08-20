import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/reminder_model.dart';

class RemindersRepository {
  RemindersRepository(this._database, this._uuid);

  final AppDatabase _database;
  final Uuid _uuid;

  // ---------------------------------------------------------------------------
  // Watch / Query
  // ---------------------------------------------------------------------------

  Stream<List<ReminderModel>> watchReminders({
    String searchQuery = '',
    String? priorityFilter,
    bool? doneFilter,
    String? schemeFilter,
    String? siteFilter,
  }) {
    final cleanQuery = searchQuery.trim();
    final cleanPriority = priorityFilter?.trim() ?? '';
    final cleanScheme = schemeFilter?.trim() ?? '';
    final cleanSite = siteFilter?.trim() ?? '';

    // doneFilter: null = all, true = done only, false = pending only
    final doneInt = doneFilter == null ? -1 : (doneFilter ? 1 : 0);

    const querySql = '''
      SELECT
        r.id,
        r.title,
        r.description,
        r.due_at,
        r.priority,
        r.is_done,
        r.done_at,
        r.scheme_id,
        sc.name  AS scheme_name,
        r.site_id,
        st.name  AS site_name,
        r.remarks,
        r.created_at
      FROM reminders r
      LEFT JOIN schemes sc ON sc.id = r.scheme_id AND sc.deleted_at IS NULL
      LEFT JOIN sites   st ON st.id = r.site_id   AND st.deleted_at IS NULL
      WHERE r.deleted_at IS NULL
        AND (? = -1 OR r.is_done = ?)
        AND (? = '' OR r.priority = ?)
        AND (? = '' OR r.scheme_id = ?)
        AND (? = '' OR r.site_id = ?)
        AND (
          ? = ''
          OR LOWER(r.title)       LIKE LOWER(?)
          OR LOWER(r.description) LIKE LOWER(?)
          OR LOWER(r.remarks)     LIKE LOWER(?)
        )
      ORDER BY r.is_done ASC, r.due_at ASC NULLS LAST, r.created_at DESC
    ''';
    final pattern = '%$cleanQuery%';

    return _database
        .customSelect(
          querySql,
          variables: [
            Variable.withInt(doneInt),
            Variable.withInt(doneInt),
            Variable.withString(cleanPriority),
            Variable.withString(cleanPriority),
            Variable.withString(cleanScheme),
            Variable.withString(cleanScheme),
            Variable.withString(cleanSite),
            Variable.withString(cleanSite),
            Variable.withString(cleanQuery),
            Variable.withString(pattern),
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {_database.reminders, _database.schemes, _database.sites},
        )
        .watch()
        .map((rows) => rows.map(_reminderFromRow).toList());
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<ReminderModel?> getById(String id) async {
    final rows = await _database
        .customSelect(
          '''SELECT r.id, r.title, r.description, r.due_at, r.priority,
                r.is_done, r.done_at, r.scheme_id, sc.name AS scheme_name,
                r.site_id, st.name AS site_name, r.remarks, r.created_at
         FROM reminders r
         LEFT JOIN schemes sc ON sc.id = r.scheme_id AND sc.deleted_at IS NULL
         LEFT JOIN sites st ON st.id = r.site_id AND st.deleted_at IS NULL
         WHERE r.id = ? AND r.deleted_at IS NULL''',
          variables: [Variable.withString(id)],
          readsFrom: {_database.reminders, _database.schemes, _database.sites},
        )
        .get();
    return rows.isEmpty ? null : _reminderFromRow(rows.single);
  }

  Stream<List<ReminderModel>> watchRemindersForDate(DateTime date) {
    final localDate = date.toLocal();
    final start = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    ).toUtc();
    return _watchDueBetween(start, start.add(const Duration(days: 1)));
  }

  Stream<List<ReminderModel>> watchUpcomingReminders({DateTime? from}) {
    return _watchDueBetween(
      (from ?? DateTime.now()).toUtc(),
      null,
      pendingOnly: true,
    );
  }

  Stream<List<ReminderModel>> watchOverdueReminders({DateTime? at}) {
    return _watchDueQuery('r.due_at < ? AND r.is_done = 0', [
      Variable.withDateTime((at ?? DateTime.now()).toUtc()),
    ]);
  }

  Stream<List<ReminderModel>> _watchDueBetween(
    DateTime start,
    DateTime? end, {
    bool pendingOnly = false,
  }) {
    final endClause = end == null ? '' : 'AND r.due_at < ?';
    final pendingClause = pendingOnly ? 'AND r.is_done = 0' : '';
    return _watchDueQuery('r.due_at >= ? $endClause $pendingClause', [
      Variable.withDateTime(start),
      if (end != null) Variable.withDateTime(end),
    ]);
  }

  Stream<List<ReminderModel>> _watchDueQuery(
    String predicate,
    List<Variable<Object>> variables,
  ) {
    return _database
        .customSelect(
          '''SELECT r.id, r.title, r.description, r.due_at, r.priority,
                r.is_done, r.done_at, r.scheme_id, sc.name AS scheme_name,
                r.site_id, st.name AS site_name, r.remarks, r.created_at
         FROM reminders r
         LEFT JOIN schemes sc ON sc.id = r.scheme_id AND sc.deleted_at IS NULL
         LEFT JOIN sites st ON st.id = r.site_id AND st.deleted_at IS NULL
         WHERE r.deleted_at IS NULL AND $predicate
         ORDER BY r.due_at ASC, r.created_at ASC, r.id ASC''',
          variables: variables,
          readsFrom: {_database.reminders, _database.schemes, _database.sites},
        )
        .watch()
        .map((rows) => rows.map(_reminderFromRow).toList());
  }

  Future<void> restoreReminder(String id) async {
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await (_database.update(
        _database.reminders,
      )..where((r) => r.id.equals(id))).write(
        RemindersCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _enqueueChange('reminder', id, 'restore', now);
    });
  }

  Future<void> createReminderWithRelationship({
    required String title,
    required String entityType,
    required String entityId,
    String? description,
    DateTime? dueAt,
    String priority = 'medium',
    String? remarks,
  }) async {
    await _ensureEntityExists(entityType, entityId);
    final now = DateTime.now().toUtc();
    final reminderId = _uuid.v4();
    await _database.transaction(() async {
      await _database
          .into(_database.reminders)
          .insert(
            RemindersCompanion.insert(
              id: reminderId,
              title: title.trim(),
              description: Value(_cleanOptional(description)),
              dueAt: Value(dueAt?.toUtc()),
              priority: Value(
                priority.trim().isEmpty ? 'medium' : priority.trim(),
              ),
              remarks: Value(_cleanOptional(remarks)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _database
          .into(_database.reminderEntityLinks)
          .insert(
            ReminderEntityLinksCompanion.insert(
              id: _uuid.v4(),
              reminderId: reminderId,
              entityType: entityType,
              entityId: entityId,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueueChange('reminder', reminderId, 'create', now);
    });
  }

  Stream<List<ReminderModel>> watchRemindersForEntity(
    String entityType,
    String entityId,
  ) {
    return _database
        .customSelect(
          '''SELECT r.id, r.title, r.description, r.due_at, r.priority,
                r.is_done, r.done_at, r.scheme_id, sc.name AS scheme_name,
                r.site_id, st.name AS site_name, r.remarks, r.created_at
         FROM reminders r
         INNER JOIN reminder_entity_links l ON l.reminder_id = r.id
         LEFT JOIN schemes sc ON sc.id = r.scheme_id AND sc.deleted_at IS NULL
         LEFT JOIN sites st ON st.id = r.site_id AND st.deleted_at IS NULL
         WHERE r.deleted_at IS NULL AND l.deleted_at IS NULL
           AND l.entity_type = ? AND l.entity_id = ?
         ORDER BY r.due_at ASC, r.created_at ASC, r.id ASC''',
          variables: [
            Variable.withString(entityType),
            Variable.withString(entityId),
          ],
          readsFrom: {
            _database.reminders,
            _database.reminderEntityLinks,
            _database.schemes,
            _database.sites,
          },
        )
        .watch()
        .map((rows) => rows.map(_reminderFromRow).toList());
  }

  Future<void> createReminder({
    required String title,
    String? description,
    DateTime? dueAt,
    String priority = 'medium',
    String? schemeId,
    String? siteId,
    String? remarks,
  }) async {
    final now = DateTime.now().toUtc();
    final reminderId = _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.reminders)
          .insert(
            RemindersCompanion.insert(
              id: reminderId,
              title: title.trim(),
              description: Value(_cleanOptional(description)),
              dueAt: Value(dueAt?.toUtc()),
              priority: Value(
                priority.trim().isEmpty ? 'medium' : priority.trim(),
              ),
              schemeId: Value(_cleanOptional(schemeId)),
              siteId: Value(_cleanOptional(siteId)),
              remarks: Value(_cleanOptional(remarks)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueueChange('reminder', reminderId, 'create', now);
    });
  }

  Future<void> updateReminder({
    required String id,
    required String title,
    String? description,
    DateTime? dueAt,
    required String priority,
    String? schemeId,
    String? siteId,
    String? remarks,
  }) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.reminders,
      )..where((r) => r.id.equals(id))).write(
        RemindersCompanion(
          title: Value(title.trim()),
          description: Value(_cleanOptional(description)),
          dueAt: Value(dueAt?.toUtc()),
          priority: Value(priority.trim()),
          schemeId: Value(_cleanOptional(schemeId)),
          siteId: Value(_cleanOptional(siteId)),
          remarks: Value(_cleanOptional(remarks)),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _enqueueChange('reminder', id, 'update', now);
    });
  }

  Future<void> markDone(String id, {bool done = true}) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.reminders,
      )..where((r) => r.id.equals(id))).write(
        RemindersCompanion(
          isDone: Value(done),
          doneAt: Value(done ? now : null),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _enqueueChange('reminder', id, 'update', now);
    });
  }

  Future<void> deleteReminder(String id) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.reminders,
      )..where((r) => r.id.equals(id))).write(
        RemindersCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pendingDelete.databaseValue),
        ),
      );
      await _enqueueChange('reminder', id, 'delete', now);
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  Future<void> _ensureEntityExists(String entityType, String entityId) async {
    const tables = {
      'scheme': 'schemes',
      'site': 'sites',
      'bill': 'bills',
      'progress': 'progress_updates',
      'person': 'people',
    };
    final table = tables[entityType.trim().toLowerCase()];
    if (table == null) throw ArgumentError.value(entityType, 'entityType');
    final row = await _database
        .customSelect(
          'SELECT id FROM $table WHERE id = ? AND deleted_at IS NULL',
          variables: [Variable.withString(entityId)],
        )
        .getSingleOrNull();
    if (row == null) throw ArgumentError.value(entityId, 'entityId');
  }

  ReminderModel _reminderFromRow(QueryRow row) {
    return ReminderModel(
      id: row.read<String>('id'),
      title: row.read<String>('title'),
      description: row.readNullable<String>('description'),
      dueAt: row.readNullable<DateTime>('due_at'),
      priority: row.read<String>('priority'),
      isDone: row.read<bool>('is_done'),
      doneAt: row.readNullable<DateTime>('done_at'),
      schemeId: row.readNullable<String>('scheme_id'),
      schemeName: row.readNullable<String>('scheme_name'),
      siteId: row.readNullable<String>('site_id'),
      siteName: row.readNullable<String>('site_name'),
      remarks: row.readNullable<String>('remarks'),
      createdAt: row.read<DateTime>('created_at'),
    );
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
