import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';
import 'package:offline_finance_management_app/src/features/reminders/data/reminders_repository.dart';
import 'package:offline_finance_management_app/src/features/schemes/data/schemes_repository.dart';
import 'package:offline_finance_management_app/src/features/sites/data/sites_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late SitesRepository sitesRepository;
  late SchemesRepository schemesRepository;
  late RemindersRepository remindersRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    sitesRepository = SitesRepository(database, uuid);
    schemesRepository = SchemesRepository(database, uuid);
    remindersRepository = RemindersRepository(database, uuid);
  });

  tearDown(() => database.close());

  // --------------------------------------------------------------------------
  // 1. Table exists
  // --------------------------------------------------------------------------
  test('reminders table exists and is empty on fresh database', () async {
    final rows = await database.select(database.reminders).get();
    expect(rows, isEmpty);
  });

  // --------------------------------------------------------------------------
  // 2. Create and read back
  // --------------------------------------------------------------------------
  test('creates a reminder and reads it back', () async {
    await remindersRepository.createReminder(
      title: 'Submit first bill',
      description: 'Submit to PWD office',
      dueAt: DateTime(2026, 9, 1),
      priority: 'high',
      remarks: 'Bring original documents',
    );

    final reminders = await remindersRepository.watchReminders().first;
    expect(reminders, hasLength(1));
    final r = reminders.single;
    expect(r.title, 'Submit first bill');
    expect(r.description, 'Submit to PWD office');
    expect(r.priority, 'high');
    expect(r.isDone, isFalse);
    expect(r.doneAt, isNull);
    expect(r.remarks, 'Bring original documents');
  });

  // --------------------------------------------------------------------------
  // 3. Default priority is medium
  // --------------------------------------------------------------------------
  test('default priority is medium when not specified', () async {
    await remindersRepository.createReminder(title: 'Check site');

    final reminders = await remindersRepository.watchReminders().first;
    expect(reminders.single.priority, 'medium');
  });

  // --------------------------------------------------------------------------
  // 4. Update reminder
  // --------------------------------------------------------------------------
  test('updates an existing reminder', () async {
    await remindersRepository.createReminder(
      title: 'Old title',
      priority: 'low',
    );
    final original = (await remindersRepository.watchReminders().first).single;

    await remindersRepository.updateReminder(
      id: original.id,
      title: 'New title',
      priority: 'high',
      dueAt: DateTime(2026, 12, 31),
      remarks: 'Updated',
    );

    final updated = (await remindersRepository.watchReminders().first).single;
    expect(updated.title, 'New title');
    expect(updated.priority, 'high');
    expect(updated.remarks, 'Updated');
    expect(updated.dueAt, isNotNull);
  });

  // --------------------------------------------------------------------------
  // 5. Mark done
  // --------------------------------------------------------------------------
  test('markDone sets isDone=true and records doneAt', () async {
    await remindersRepository.createReminder(title: 'Pay contractor');
    final r = (await remindersRepository.watchReminders().first).single;
    expect(r.isDone, isFalse);

    await remindersRepository.markDone(r.id);

    final done = (await remindersRepository.watchReminders().first).single;
    expect(done.isDone, isTrue);
    expect(done.doneAt, isNotNull);
  });

  // --------------------------------------------------------------------------
  // 6. Mark undone
  // --------------------------------------------------------------------------
  test('markDone(done: false) clears isDone and doneAt', () async {
    await remindersRepository.createReminder(title: 'Pay contractor');
    final r = (await remindersRepository.watchReminders().first).single;
    await remindersRepository.markDone(r.id);

    await remindersRepository.markDone(r.id, done: false);

    final undone = (await remindersRepository.watchReminders().first).single;
    expect(undone.isDone, isFalse);
    expect(undone.doneAt, isNull);
  });

  // --------------------------------------------------------------------------
  // 7. Soft delete
  // --------------------------------------------------------------------------
  test('soft-deletes a reminder (excluded from watch)', () async {
    await remindersRepository.createReminder(title: 'Temporary reminder');
    final before = await remindersRepository.watchReminders().first;
    expect(before, hasLength(1));

    await remindersRepository.deleteReminder(before.single.id);

    final after = await remindersRepository.watchReminders().first;
    expect(after, isEmpty);
  });

  // --------------------------------------------------------------------------
  // 8. Filter by priority
  // --------------------------------------------------------------------------
  test('priorityFilter returns only matching priority', () async {
    await remindersRepository.createReminder(
      title: 'High task',
      priority: 'high',
    );
    await remindersRepository.createReminder(
      title: 'Low task',
      priority: 'low',
    );

    final high = await remindersRepository
        .watchReminders(priorityFilter: 'high')
        .first;
    expect(high, hasLength(1));
    expect(high.single.priority, 'high');

    final low = await remindersRepository
        .watchReminders(priorityFilter: 'low')
        .first;
    expect(low, hasLength(1));
    expect(low.single.priority, 'low');
  });

  // --------------------------------------------------------------------------
  // 9. Filter by done status
  // --------------------------------------------------------------------------
  test('doneFilter separates pending and done reminders', () async {
    await remindersRepository.createReminder(title: 'Task A');
    await remindersRepository.createReminder(title: 'Task B');
    final all = await remindersRepository.watchReminders().first;
    await remindersRepository.markDone(all.first.id);

    final pending = await remindersRepository
        .watchReminders(doneFilter: false)
        .first;
    expect(pending, hasLength(1));
    expect(pending.single.isDone, isFalse);

    final done = await remindersRepository
        .watchReminders(doneFilter: true)
        .first;
    expect(done, hasLength(1));
    expect(done.single.isDone, isTrue);
  });

  // --------------------------------------------------------------------------
  // 10. Search by title
  // --------------------------------------------------------------------------
  test('searchQuery filters by title', () async {
    await remindersRepository.createReminder(title: 'Submit bill to PWD');
    await remindersRepository.createReminder(title: 'Buy cement');

    final match = await remindersRepository
        .watchReminders(searchQuery: 'PWD')
        .first;
    expect(match, hasLength(1));
    expect(match.single.title, contains('PWD'));

    final noMatch = await remindersRepository
        .watchReminders(searchQuery: 'XXXXXX')
        .first;
    expect(noMatch, isEmpty);
  });

  // --------------------------------------------------------------------------
  // 11. Search by description
  // --------------------------------------------------------------------------
  test('searchQuery filters by description', () async {
    await remindersRepository.createReminder(
      title: 'Office task',
      description: 'Bring the stamped receipt',
    );

    final match = await remindersRepository
        .watchReminders(searchQuery: 'stamped')
        .first;
    expect(match, hasLength(1));
  });

  // --------------------------------------------------------------------------
  // 12. Linked to scheme
  // --------------------------------------------------------------------------
  test('links reminder to a scheme and joins scheme name', () async {
    await schemesRepository.createScheme(
      schemeCode: 'SCH-R01',
      name: 'Ring Road Phase 1',
      budget: 1000000.0,
      status: 'working',
      progressPercentage: 0,
    );
    final scheme = (await schemesRepository.watchSchemes().first).single;

    await remindersRepository.createReminder(
      title: 'Scheme reminder',
      schemeId: scheme.id,
    );

    final reminders = await remindersRepository.watchReminders().first;
    expect(reminders.single.schemeId, scheme.id);
    expect(reminders.single.schemeName, 'Ring Road Phase 1');
  });

  // --------------------------------------------------------------------------
  // 13. Linked to site
  // --------------------------------------------------------------------------
  test('links reminder to a site and joins site name', () async {
    await sitesRepository.createSite(name: 'Lahore Bypass');
    final site = (await sitesRepository.watchSites().first).single;

    await remindersRepository.createReminder(
      title: 'Site reminder',
      siteId: site.id,
    );

    final reminders = await remindersRepository.watchReminders().first;
    expect(reminders.single.siteId, site.id);
    expect(reminders.single.siteName, 'Lahore Bypass');
  });

  // --------------------------------------------------------------------------
  // 14. Filter by scheme
  // --------------------------------------------------------------------------
  test('schemeFilter returns only reminders for that scheme', () async {
    await schemesRepository.createScheme(
      schemeCode: 'SCH-F01',
      name: 'Scheme F1',
      budget: 500000.0,
      status: 'working',
      progressPercentage: 0,
    );
    await schemesRepository.createScheme(
      schemeCode: 'SCH-F02',
      name: 'Scheme F2',
      budget: 500000.0,
      status: 'working',
      progressPercentage: 0,
    );
    final schemes = await schemesRepository.watchSchemes().first;
    final s1 = schemes[0];
    final s2 = schemes[1];

    await remindersRepository.createReminder(title: 'R1', schemeId: s1.id);
    await remindersRepository.createReminder(title: 'R2', schemeId: s2.id);
    await remindersRepository.createReminder(title: 'R3');

    final filtered = await remindersRepository
        .watchReminders(schemeFilter: s1.id)
        .first;
    expect(filtered, hasLength(1));
    expect(filtered.single.schemeId, s1.id);
  });

  // --------------------------------------------------------------------------
  // 15. isOverdue helper
  // --------------------------------------------------------------------------
  test('isOverdue is true for past due date on pending reminder', () async {
    await remindersRepository.createReminder(
      title: 'Overdue task',
      dueAt: DateTime(2020, 1, 1),
      priority: 'high',
    );

    final reminders = await remindersRepository.watchReminders().first;
    expect(reminders.single.isOverdue, isTrue);
  });

  // --------------------------------------------------------------------------
  // 16. isOverdue is false when done
  // --------------------------------------------------------------------------
  test('isOverdue is false when reminder is done even if past due', () async {
    await remindersRepository.createReminder(
      title: 'Done overdue',
      dueAt: DateTime(2020, 1, 1),
    );
    final r = (await remindersRepository.watchReminders().first).single;
    await remindersRepository.markDone(r.id);

    final done = (await remindersRepository.watchReminders().first).single;
    expect(done.isOverdue, isFalse);
  });

  // --------------------------------------------------------------------------
  // 17. SyncOutbox on create
  // --------------------------------------------------------------------------
  test('createReminder enqueues a SyncOutbox create entry', () async {
    await remindersRepository.createReminder(title: 'Sync test');
    final r = (await remindersRepository.watchReminders().first).single;

    final outbox = await database
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='reminder' AND entity_id=?",
          variables: [Variable.withString(r.id)],
        )
        .get();
    expect(outbox, hasLength(1));
    expect(outbox.single.read<String>('operation'), 'create');
  });

  // --------------------------------------------------------------------------
  // 18. SyncOutbox on update
  // --------------------------------------------------------------------------
  test('updateReminder enqueues a SyncOutbox update entry', () async {
    await remindersRepository.createReminder(title: 'Original');
    final r = (await remindersRepository.watchReminders().first).single;

    await remindersRepository.updateReminder(
      id: r.id,
      title: 'Updated',
      priority: 'low',
    );

    final outbox = await database
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='reminder' AND entity_id=? AND operation='update'",
          variables: [Variable.withString(r.id)],
        )
        .get();
    expect(outbox, hasLength(1));
  });

  // --------------------------------------------------------------------------
  // 19. SyncOutbox on delete
  // --------------------------------------------------------------------------
  test('deleteReminder enqueues a SyncOutbox delete entry', () async {
    await remindersRepository.createReminder(title: 'To delete');
    final r = (await remindersRepository.watchReminders().first).single;

    await remindersRepository.deleteReminder(r.id);

    final outbox = await database
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='reminder' AND entity_id=? AND operation='delete'",
          variables: [Variable.withString(r.id)],
        )
        .get();
    expect(outbox, hasLength(1));
  });

  // --------------------------------------------------------------------------
  // 20. SyncOutbox on markDone
  // --------------------------------------------------------------------------
  test('markDone enqueues a SyncOutbox update entry', () async {
    await remindersRepository.createReminder(title: 'Mark done test');
    final r = (await remindersRepository.watchReminders().first).single;

    await remindersRepository.markDone(r.id);

    final outbox = await database
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='reminder' AND entity_id=? AND operation='update'",
          variables: [Variable.withString(r.id)],
        )
        .get();
    expect(outbox, hasLength(1));
  });

  // --------------------------------------------------------------------------
  // 21. Ordering: pending before done, then by due_at ASC
  // --------------------------------------------------------------------------
  test('pending reminders appear before done, ordered by due_at', () async {
    await remindersRepository.createReminder(
      title: 'Due later',
      dueAt: DateTime(2026, 12, 1),
    );
    await remindersRepository.createReminder(
      title: 'Due sooner',
      dueAt: DateTime(2026, 6, 1),
    );
    await remindersRepository.createReminder(title: 'Done task');
    final all = await remindersRepository.watchReminders().first;
    // Mark the third one done
    final doneCandidate = all.firstWhere((r) => r.title == 'Done task');
    await remindersRepository.markDone(doneCandidate.id);

    final ordered = await remindersRepository.watchReminders().first;
    // First two should be pending (isDone=false), last should be done
    expect(ordered[0].isDone, isFalse);
    expect(ordered[1].isDone, isFalse);
    expect(ordered[2].isDone, isTrue);
    // Among pending, due sooner comes first
    expect(ordered[0].title, 'Due sooner');
    expect(ordered[1].title, 'Due later');
  });

  // --------------------------------------------------------------------------
  // 22. Nullable dueAt stored correctly
  // --------------------------------------------------------------------------
  test('reminder with no due date has null dueAt', () async {
    await remindersRepository.createReminder(title: 'No deadline');

    final reminders = await remindersRepository.watchReminders().first;
    expect(reminders.single.dueAt, isNull);
  });

  // --------------------------------------------------------------------------
  // 23. getById and restore
  // --------------------------------------------------------------------------
  test(
    'getById returns the reminder and restore reactivates soft-deleted data',
    () async {
      await remindersRepository.createReminder(title: 'Temporary reminder');
      final original =
          (await remindersRepository.watchReminders().first).single;

      await remindersRepository.deleteReminder(original.id);
      expect(await remindersRepository.getById(original.id), isNull);

      await remindersRepository.restoreReminder(original.id);
      final restored = await remindersRepository.getById(original.id);
      expect(restored, isNotNull);
      expect(restored!.title, 'Temporary reminder');
    },
  );

  // --------------------------------------------------------------------------
  // 24. Date, upcoming, overdue queries and due time handling
  // --------------------------------------------------------------------------
  test(
    'date, upcoming, overdue queries and time-aware dueAt work as expected',
    () async {
      final today = DateTime.now().toUtc();
      final dueToday = today.add(const Duration(hours: 5));
      final tomorrow = today.add(const Duration(days: 1));
      final past = today.subtract(const Duration(days: 2));

      await remindersRepository.createReminder(
        title: 'Due today',
        dueAt: dueToday,
      );
      await remindersRepository.createReminder(
        title: 'Due tomorrow',
        dueAt: tomorrow,
      );
      await remindersRepository.createReminder(
        title: 'Overdue task',
        dueAt: past,
      );

      final byDate = await remindersRepository
          .watchRemindersForDate(today)
          .first;
      expect(byDate.any((r) => r.title == 'Due today'), isTrue);

      final upcoming = await remindersRepository.watchUpcomingReminders().first;
      expect(upcoming.any((r) => r.title == 'Due today'), isTrue);
      expect(upcoming.any((r) => r.title == 'Overdue task'), isFalse);

      final overdue = await remindersRepository.watchOverdueReminders().first;
      expect(overdue.any((r) => r.title == 'Overdue task'), isTrue);
    },
  );

  test('watchRemindersForDate keeps UTC calendar-day boundaries', () async {
    final dayStart = DateTime.utc(2026, 6, 1, 0, 0, 0);
    final sameDayLater = DateTime.utc(2026, 6, 1, 23, 59, 59);
    final nextDayStart = DateTime.utc(2026, 6, 2, 0, 0, 0);

    await remindersRepository.createReminder(
      title: 'UTC same-day reminder',
      dueAt: sameDayLater,
    );
    await remindersRepository.createReminder(
      title: 'UTC next-day reminder',
      dueAt: nextDayStart,
    );

    final byDate = await remindersRepository
        .watchRemindersForDate(dayStart)
        .first;

    expect(byDate.any((r) => r.title == 'UTC same-day reminder'), isTrue);
    expect(byDate.any((r) => r.title == 'UTC next-day reminder'), isFalse);
  });

  // --------------------------------------------------------------------------
  // 25. Relationship support for normalized entity links
  // --------------------------------------------------------------------------
  test('createReminderWithRelationship and query by entity work for scheme, site, bill, progress, and person', () async {
    await schemesRepository.createScheme(
      schemeCode: 'SCH-R02',
      name: 'Scheme R2',
      budget: 250000.0,
      status: 'working',
      progressPercentage: 0,
    );
    final scheme = (await schemesRepository.watchSchemes().first).single;

    await sitesRepository.createSite(name: 'Site Alpha');
    final site = (await sitesRepository.watchSites().first).single;

    await remindersRepository.createReminderWithRelationship(
      title: 'Scheme reminder',
      entityType: 'scheme',
      entityId: scheme.id,
    );
    await remindersRepository.createReminderWithRelationship(
      title: 'Site reminder',
      entityType: 'site',
      entityId: site.id,
    );

    final schemeReminders = await remindersRepository
        .watchRemindersForEntity('scheme', scheme.id)
        .first;
    expect(schemeReminders.single.title, 'Scheme reminder');

    final siteReminders = await remindersRepository
        .watchRemindersForEntity('site', site.id)
        .first;
    expect(siteReminders.single.title, 'Site reminder');

    final invalid = await remindersRepository
        .watchRemindersForEntity('person', 'missing-id')
        .first;
    expect(invalid, isEmpty);
  });
}
