import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/reminder_model.dart';
import '../services/reminder_notification_service.dart';

class RemindersRepository {
  RemindersRepository(
    this._database,
    this._uuid, {
    ReminderNotificationService? notifications,
  }) : _notifications = notifications ?? ReminderNotificationService();

  final AppDatabase _database;
  final Uuid _uuid;
  final ReminderNotificationService _notifications;

  Stream<List<ReminderModel>> watchReminders({
    String searchQuery = '',
    String? priorityFilter,
    bool? doneFilter,
    String? schemeFilter,
    String? siteFilter,
  }) {
    final query = searchQuery.trim();
    final priority = priorityFilter?.trim() ?? '';
    final scheme = schemeFilter?.trim() ?? '';
    final site = siteFilter?.trim() ?? '';
    final done = doneFilter == null ? -1 : (doneFilter ? 1 : 0);
    const sql = '''
      SELECT r.id, r.title, r.description, r.due_at, r.priority, r.is_done,
             r.done_at, r.scheme_id, sc.name AS scheme_name, r.site_id,
             st.name AS site_name, r.remarks, r.created_at
      FROM reminders r
      LEFT JOIN schemes sc ON sc.id = r.scheme_id AND sc.deleted_at IS NULL
      LEFT JOIN sites st ON st.id = r.site_id AND st.deleted_at IS NULL
      WHERE r.deleted_at IS NULL
        AND (? = -1 OR r.is_done = ?)
        AND (? = '' OR r.priority = ?)
        AND (? = '' OR r.scheme_id = ?)
        AND (? = '' OR r.site_id = ?)
        AND (? = '' OR LOWER(r.title) LIKE LOWER(?)
          OR LOWER(r.description) LIKE LOWER(?) OR LOWER(r.remarks) LIKE LOWER(?))
      ORDER BY r.is_done ASC, r.due_at ASC NULLS LAST, r.created_at DESC, r.id ASC
    ''';
    final pattern = '%$query%';
    return _database
        .customSelect(
          sql,
          variables: [
            Variable.withInt(done),
            Variable.withInt(done),
            Variable.withString(priority),
            Variable.withString(priority),
            Variable.withString(scheme),
            Variable.withString(scheme),
            Variable.withString(site),
            Variable.withString(site),
            Variable.withString(query),
            Variable.withString(pattern),
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {_database.reminders, _database.schemes, _database.sites},
        )
        .watch()
        .map((rows) => rows.map(_reminderFromRow).toList());
  }

  Future<ReminderModel?> getById(String id) async {
    final rows = await _database
        .customSelect(
          '''SELECT r.id, r.title, r.description, r.due_at, r.priority, r.is_done,
             r.done_at, r.scheme_id, sc.name AS scheme_name, r.site_id,
             st.name AS site_name, r.remarks, r.created_at
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
    final local = date.toLocal();
    final start = DateTime(local.year, local.month, local.day).toUtc();
    return _watchDueQuery('r.due_at >= ? AND r.due_at < ?', [
      Variable.withDateTime(start),
      Variable.withDateTime(start.add(const Duration(days: 1))),
    ]);
  }

  Stream<List<ReminderModel>> watchUpcomingReminders({DateTime? from}) {
    return _watchDueQuery('r.due_at >= ? AND r.is_done = 0', [
      Variable.withDateTime((from ?? DateTime.now()).toUtc()),
    ]);
  }

  Stream<List<ReminderModel>> watchOverdueReminders({DateTime? at}) {
    return _watchDueQuery('r.due_at < ? AND r.is_done = 0', [
      Variable.withDateTime((at ?? DateTime.now()).toUtc()),
    ]);
  }

  Stream<List<ReminderModel>> _watchDueQuery(
    String predicate,
    List<Variable<Object>> variables,
  ) {
    return _database
        .customSelect(
          '''
      SELECT r.id, r.title, r.description, r.due_at, r.priority, r.is_done,
             r.done_at, r.scheme_id, sc.name AS scheme_name, r.site_id,
             st.name AS site_name, r.remarks, r.created_at
      FROM reminders r
      LEFT JOIN schemes sc ON sc.id = r.scheme_id AND sc.deleted_at IS NULL
      LEFT JOIN sites st ON st.id = r.site_id AND st.deleted_at IS NULL
      WHERE r.deleted_at IS NULL AND $predicate
      ORDER BY r.due_at ASC, r.created_at ASC, r.id ASC
    ''',
          variables: variables,
          readsFrom: {_database.reminders, _database.schemes, _database.sites},
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
    final id = _uuid.v4();
    await _database.transaction(() async {
      await _insertReminder(
        id: id,
        title: title,
        description: description,
        dueAt: dueAt,
        priority: priority,
        schemeId: schemeId,
        siteId: siteId,
        remarks: remarks,
        now: now,
      );
      await _enqueueChange('reminder', id, 'create', now);
    });
    await _schedule(id, title, dueAt);
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
          description: Value(_clean(description)),
          dueAt: Value(dueAt?.toUtc()),
          priority: Value(priority.trim()),
          schemeId: Value(_clean(schemeId)),
          siteId: Value(_clean(siteId)),
          remarks: Value(_clean(remarks)),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _enqueueChange('reminder', id, 'update', now);
    });
    await _schedule(id, title, dueAt);
  }

  Future<void> markDone(String id, {bool done = true}) async {
    final now = DateTime.now().toUtc();
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
    if (done) {
      await _notifications.cancel(id);
    } else {
      final reminder = await getById(id);
      if (reminder?.dueAt != null) {
        await _schedule(id, reminder!.title, reminder.dueAt);
      }
    }
  }

  Future<void> deleteReminder(String id) async {
    final now = DateTime.now().toUtc();
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
    await _notifications.cancel(id);
  }

  Future<void> restoreReminder(String id) async {
    final now = DateTime.now().toUtc();
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
    final reminder = await getById(id);
    if (reminder?.dueAt != null && !reminder!.isDone) {
      await _schedule(id, reminder.title, reminder.dueAt);
    }
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
    final id = _uuid.v4();
    await _database.transaction(() async {
      await _insertReminder(
        id: id,
        title: title,
        description: description,
        dueAt: dueAt,
        priority: priority,
        remarks: remarks,
        now: now,
      );
      await _database
          .into(_database.reminderEntityLinks)
          .insert(
            ReminderEntityLinksCompanion.insert(
              id: _uuid.v4(),
              reminderId: id,
              entityType: entityType.trim().toLowerCase(),
              entityId: entityId,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueueChange('reminder', id, 'create', now);
    });
    await _schedule(id, title, dueAt);
  }

  Stream<List<ReminderModel>> watchRemindersForEntity(String type, String id) {
    return _database
        .customSelect(
          '''
      SELECT r.id, r.title, r.description, r.due_at, r.priority, r.is_done,
             r.done_at, r.scheme_id, sc.name AS scheme_name, r.site_id,
             st.name AS site_name, r.remarks, r.created_at,
             l.entity_type AS related_entity_type,
             l.entity_id AS related_entity_id,
             CASE l.entity_type
               WHEN 'scheme' THEN (SELECT name FROM schemes WHERE id = l.entity_id)
               WHEN 'site' THEN (SELECT name FROM sites WHERE id = l.entity_id)
               WHEN 'bill' THEN (SELECT COALESCE(bill_number, bill_type) FROM bills WHERE id = l.entity_id)
               WHEN 'progress' THEN (SELECT COALESCE(result, status) FROM progress_updates WHERE id = l.entity_id)
               WHEN 'person' THEN (SELECT full_name FROM people WHERE id = l.entity_id)
             END AS related_entity_name
      FROM reminders r JOIN reminder_entity_links l ON l.reminder_id = r.id
      LEFT JOIN schemes sc ON sc.id = r.scheme_id AND sc.deleted_at IS NULL
      LEFT JOIN sites st ON st.id = r.site_id AND st.deleted_at IS NULL
      WHERE r.deleted_at IS NULL AND l.deleted_at IS NULL
        AND l.entity_type = ? AND l.entity_id = ?
      ORDER BY r.due_at ASC, r.created_at ASC, r.id ASC
    ''',
          variables: [Variable.withString(type), Variable.withString(id)],
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

  Future<void> updateReminderRelationship({
    required String reminderId,
    required String entityType,
    required String entityId,
  }) async {
    await _ensureEntityExists(entityType, entityId);
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await (_database.update(
        _database.reminderEntityLinks,
      )..where((link) => link.reminderId.equals(reminderId))).write(
        ReminderEntityLinksCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _database
          .into(_database.reminderEntityLinks)
          .insert(
            ReminderEntityLinksCompanion.insert(
              id: _uuid.v4(),
              reminderId: reminderId,
              entityType: entityType.trim().toLowerCase(),
              entityId: entityId,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueueChange('reminder', reminderId, 'update', now);
    });
  }

  Future<void> _insertReminder({
    required String id,
    required String title,
    String? description,
    DateTime? dueAt,
    required String priority,
    String? schemeId,
    String? siteId,
    String? remarks,
    required DateTime now,
  }) async {
    await _database
        .into(_database.reminders)
        .insert(
          RemindersCompanion.insert(
            id: id,
            title: title.trim(),
            description: Value(_clean(description)),
            dueAt: Value(dueAt?.toUtc()),
            priority: Value(
              priority.trim().isEmpty ? 'medium' : priority.trim(),
            ),
            schemeId: Value(_clean(schemeId)),
            siteId: Value(_clean(siteId)),
            remarks: Value(_clean(remarks)),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> _schedule(String id, String title, DateTime? dueAt) async {
    if (dueAt == null) {
      await _notifications.cancel(id);
    } else {
      await _notifications.schedule(
        reminderId: id,
        title: title.trim(),
        dueAt: dueAt.toUtc(),
      );
    }
  }

  Future<void> _ensureEntityExists(String type, String id) async {
    const tables = {
      'scheme': 'schemes',
      'site': 'sites',
      'bill': 'bills',
      'progress': 'progress_updates',
      'person': 'people',
    };
    final table = tables[type.trim().toLowerCase()];
    if (table == null) {
      throw ArgumentError.value(type, 'entityType');
    }
    final row = await _database
        .customSelect(
          'SELECT id FROM $table WHERE id = ? AND deleted_at IS NULL',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw ArgumentError.value(id, 'entityId');
    }
  }

  Future<void> _enqueueChange(
    String type,
    String entityId,
    String operation,
    DateTime now,
  ) async {
    final existing =
        await (_database.select(_database.syncOutbox)..where(
              (e) =>
                  e.entityType.equals(type) &
                  e.entityId.equals(entityId) &
                  e.operation.equals(operation),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (_database.update(
        _database.syncOutbox,
      )..where((e) => e.id.equals(existing.id))).write(
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
              entityType: type,
              entityId: entityId,
              operation: operation,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
  }

  ReminderModel _reminderFromRow(QueryRow row) => ReminderModel(
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
    relatedEntityType: row.readNullable<String>('related_entity_type'),
    relatedEntityId: row.readNullable<String>('related_entity_id'),
    relatedEntityName: row.readNullable<String>('related_entity_name'),
    remarks: row.readNullable<String>('remarks'),
    createdAt: row.read<DateTime>('created_at'),
  );

  String? _clean(String? value) =>
      value?.trim().isEmpty ?? true ? null : value!.trim();
}
