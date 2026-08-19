import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';
import 'package:offline_finance_management_app/src/features/progress/data/progress_repository.dart';
import 'package:offline_finance_management_app/src/features/schemes/data/schemes_repository.dart';
import 'package:offline_finance_management_app/src/features/sites/data/sites_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late SitesRepository sitesRepo;
  late SchemesRepository schemesRepo;
  late ProgressRepository progressRepo;

  Future<String> createScheme({String code = 'SCH-P01', String? siteId}) async {
    await schemesRepo.createScheme(
      schemeCode: code,
      name: 'Test Scheme $code',
      budget: 1000000.0,
      siteId: siteId,
    );
    final schemes = await schemesRepo.watchSchemes().first;
    return schemes.last.id;
  }

  Future<String> createSite({String name = 'Test Site'}) async {
    await sitesRepo.createSite(name: name);
    final sites = await sitesRepo.watchSites().first;
    return sites.last.id;
  }

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    sitesRepo = SitesRepository(database, uuid);
    schemesRepo = SchemesRepository(database, uuid);
    progressRepo = ProgressRepository(database, uuid);
  });

  tearDown(() => database.close());

  // --------------------------------------------------------------------------
  // 1. Migration succeeds / table exists
  // --------------------------------------------------------------------------
  test('progress_updates table exists after migration', () async {
    final rows = await database.select(database.progressUpdates).get();
    expect(rows, isEmpty);
  });

  // --------------------------------------------------------------------------
  // 2. Existing data survives (schemes/sites unaffected)
  // --------------------------------------------------------------------------
  test('existing schemes and sites survive progress table creation', () async {
    final siteId = await createSite();
    final schemeId = await createScheme(siteId: siteId);

    final schemes = await schemesRepo.watchSchemes().first;
    final sites = await sitesRepo.watchSites().first;
    expect(schemes, hasLength(1));
    expect(sites, hasLength(1));
    expect(schemes.single.id, schemeId);
  });

  // --------------------------------------------------------------------------
  // 3. Create progress record
  // --------------------------------------------------------------------------
  test('creates a progress record and reads it back', () async {
    final schemeId = await createScheme();

    final id = await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'in_progress',
      progressPercentage: 40.0,
      date: DateTime(2026, 8, 15),
      result: 'Foundation poured',
      remarks: 'On schedule',
    );

    final updates = await progressRepo.watchProgressUpdates().first;
    expect(updates, hasLength(1));
    final u = updates.single;
    expect(u.id, id);
    expect(u.schemeId, schemeId);
    expect(u.status, 'in_progress');
    expect(u.progressPercentage, 40.0);
    expect(u.result, 'Foundation poured');
    expect(u.remarks, 'On schedule');
  });

  // --------------------------------------------------------------------------
  // 4. Read progress record — scheme name joined
  // --------------------------------------------------------------------------
  test('progress record includes joined scheme name', () async {
    final schemeId = await createScheme(code: 'SCH-JOIN');

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'working',
      progressPercentage: 10.0,
      date: DateTime(2026, 8, 1),
    );

    final updates = await progressRepo.watchProgressUpdates().first;
    expect(updates.single.schemeName, 'Test Scheme SCH-JOIN');
  });

  // --------------------------------------------------------------------------
  // 5. Update progress record
  // --------------------------------------------------------------------------
  test('updates an existing progress record', () async {
    final schemeId = await createScheme();

    final id = await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'working',
      progressPercentage: 20.0,
      date: DateTime(2026, 8, 10),
    );

    await progressRepo.updateProgress(
      id: id,
      schemeId: schemeId,
      status: 'in_progress',
      progressPercentage: 60.0,
      date: DateTime(2026, 8, 20),
      result: 'Walls completed',
    );

    final updates = await progressRepo.watchProgressUpdates().first;
    expect(updates.single.status, 'in_progress');
    expect(updates.single.progressPercentage, 60.0);
    expect(updates.single.result, 'Walls completed');
  });

  // --------------------------------------------------------------------------
  // 6. Delete/deactivate progress record (soft delete)
  // --------------------------------------------------------------------------
  test('soft-deletes a progress record (excluded from watch)', () async {
    final schemeId = await createScheme();

    final id = await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'working',
      progressPercentage: 10.0,
      date: DateTime(2026, 8, 1),
    );

    final before = await progressRepo.watchProgressUpdates().first;
    expect(before, hasLength(1));

    await progressRepo.deleteProgress(id);

    final after = await progressRepo.watchProgressUpdates().first;
    expect(after, isEmpty);

    // Verify deleted_at is set in DB
    final raw = await database
        .customSelect(
          'SELECT deleted_at FROM progress_updates WHERE id = ?',
          variables: [drift.Variable.withString(id)],
        )
        .getSingle();
    expect(raw.readNullable<DateTime>('deleted_at'), isNotNull);
  });

  // --------------------------------------------------------------------------
  // 7. Scheme relationship
  // --------------------------------------------------------------------------
  test('progress record is linked to its scheme', () async {
    final schemeId = await createScheme(code: 'SCH-REL');

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'initial',
      progressPercentage: 0.0,
      date: DateTime(2026, 8, 1),
    );

    final updates = await progressRepo.watchProgressByScheme(schemeId).first;
    expect(updates, hasLength(1));
    expect(updates.single.schemeId, schemeId);
  });

  // --------------------------------------------------------------------------
  // 8. Site relationship
  // --------------------------------------------------------------------------
  test('progress record includes site name when site is linked', () async {
    final siteId = await createSite(name: 'Ring Road Site');
    final schemeId = await createScheme(siteId: siteId);

    await progressRepo.createProgress(
      schemeId: schemeId,
      siteId: siteId,
      status: 'working',
      progressPercentage: 25.0,
      date: DateTime(2026, 8, 5),
    );

    final updates = await progressRepo.watchProgressUpdates().first;
    expect(updates.single.siteId, siteId);
    expect(updates.single.siteName, 'Ring Road Site');
  });

  // --------------------------------------------------------------------------
  // 9. Progress history — multiple records preserved
  // --------------------------------------------------------------------------
  test('progress history preserves all records in date-desc order', () async {
    final schemeId = await createScheme();

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'initial',
      progressPercentage: 0.0,
      date: DateTime(2026, 8, 10),
    );
    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'in_progress',
      progressPercentage: 40.0,
      date: DateTime(2026, 8, 15),
    );
    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'completed',
      progressPercentage: 100.0,
      date: DateTime(2026, 8, 30),
    );

    final history = await progressRepo.watchProgressByScheme(schemeId).first;
    expect(history, hasLength(3));
    // Ordered date DESC
    expect(history[0].status, 'completed');
    expect(history[1].status, 'in_progress');
    expect(history[2].status, 'initial');
  });

  // --------------------------------------------------------------------------
  // 10. Latest progress updates parent scheme status
  // --------------------------------------------------------------------------
  test(
    'creating progress updates parent scheme status and percentage',
    () async {
      final schemeId = await createScheme();

      await progressRepo.createProgress(
        schemeId: schemeId,
        status: 'in_progress',
        progressPercentage: 70.0,
        date: DateTime(2026, 8, 20),
        result: 'Roof done',
      );

      final schemes = await schemesRepo.watchSchemes().first;
      expect(schemes.single.status, 'in_progress');
      expect(schemes.single.progressPercentage, 70.0);
      expect(schemes.single.result, 'Roof done');
    },
  );

  // --------------------------------------------------------------------------
  // 11. Status filtering
  // --------------------------------------------------------------------------
  test('statusFilter returns only matching status', () async {
    final schemeId = await createScheme();

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'working',
      progressPercentage: 10.0,
      date: DateTime(2026, 8, 1),
    );
    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'completed',
      progressPercentage: 100.0,
      date: DateTime(2026, 8, 30),
    );

    final working = await progressRepo
        .watchProgressUpdates(statusFilter: 'working')
        .first;
    expect(working, hasLength(1));
    expect(working.single.status, 'working');

    final completed = await progressRepo
        .watchProgressUpdates(statusFilter: 'completed')
        .first;
    expect(completed, hasLength(1));
    expect(completed.single.status, 'completed');
  });

  // --------------------------------------------------------------------------
  // 12. Date ordering
  // --------------------------------------------------------------------------
  test('records are ordered by date descending', () async {
    final schemeId = await createScheme();

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'initial',
      progressPercentage: 0.0,
      date: DateTime(2026, 7, 1),
    );
    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'in_progress',
      progressPercentage: 50.0,
      date: DateTime(2026, 9, 1),
    );

    final all = await progressRepo.watchProgressUpdates().first;
    expect(all.first.date.isAfter(all.last.date), isTrue);
  });

  // --------------------------------------------------------------------------
  // 13. Search
  // --------------------------------------------------------------------------
  test('searchQuery filters by scheme name and result', () async {
    final schemeId = await createScheme(code: 'SCH-SRCH');

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'in_progress',
      progressPercentage: 50.0,
      date: DateTime(2026, 8, 1),
      result: 'Excavation complete',
    );

    final byScheme = await progressRepo
        .watchProgressUpdates(searchQuery: 'SCH-SRCH')
        .first;
    expect(byScheme, hasLength(1));

    final byResult = await progressRepo
        .watchProgressUpdates(searchQuery: 'Excavation')
        .first;
    expect(byResult, hasLength(1));

    final noMatch = await progressRepo
        .watchProgressUpdates(searchQuery: 'XXXXXX')
        .first;
    expect(noMatch, isEmpty);
  });

  // --------------------------------------------------------------------------
  // 14. Percentage clamped to 0–100 (above 100)
  // --------------------------------------------------------------------------
  test('percentage above 100 is clamped to 100', () async {
    final schemeId = await createScheme();

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'in_progress',
      progressPercentage: 150.0,
      date: DateTime(2026, 8, 1),
    );

    final updates = await progressRepo.watchProgressUpdates().first;
    expect(updates.single.progressPercentage, 100.0);
  });

  // --------------------------------------------------------------------------
  // 15. Incomplete reason validation
  // --------------------------------------------------------------------------
  test('incomplete reason is stored and returned correctly', () async {
    final schemeId = await createScheme();

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'incomplete',
      progressPercentage: 60.0,
      date: DateTime(2026, 8, 1),
      incompleteReason: 'Funding stopped',
      result: 'Partial road laid',
    );

    final updates = await progressRepo.watchProgressUpdates().first;
    expect(updates.single.status, 'incomplete');
    expect(updates.single.incompleteReason, 'Funding stopped');
    expect(updates.single.result, 'Partial road laid');
  });

  // --------------------------------------------------------------------------
  // 16. Create generates SyncOutbox entry
  // --------------------------------------------------------------------------
  test('createProgress enqueues a SyncOutbox entry', () async {
    final schemeId = await createScheme();

    final id = await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'working',
      progressPercentage: 10.0,
      date: DateTime(2026, 8, 1),
    );

    final outbox = await database
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='progress_update' AND entity_id=? AND operation='create'",
          variables: [drift.Variable.withString(id)],
        )
        .get();
    expect(outbox, hasLength(1));
  });

  // --------------------------------------------------------------------------
  // 17. Update generates SyncOutbox entry
  // --------------------------------------------------------------------------
  test('updateProgress enqueues a SyncOutbox update entry', () async {
    final schemeId = await createScheme();

    final id = await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'working',
      progressPercentage: 10.0,
      date: DateTime(2026, 8, 1),
    );

    await progressRepo.updateProgress(
      id: id,
      schemeId: schemeId,
      status: 'in_progress',
      progressPercentage: 50.0,
      date: DateTime(2026, 8, 15),
    );

    final outbox = await database
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='progress_update' AND entity_id=? AND operation='update'",
          variables: [drift.Variable.withString(id)],
        )
        .get();
    expect(outbox, hasLength(1));
  });

  // --------------------------------------------------------------------------
  // 18. Delete generates SyncOutbox entry
  // --------------------------------------------------------------------------
  test('deleteProgress enqueues a SyncOutbox delete entry', () async {
    final schemeId = await createScheme();

    final id = await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'working',
      progressPercentage: 10.0,
      date: DateTime(2026, 8, 1),
    );

    await progressRepo.deleteProgress(id);

    final outbox = await database
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='progress_update' AND entity_id=? AND operation='delete'",
          variables: [drift.Variable.withString(id)],
        )
        .get();
    expect(outbox, hasLength(1));
  });

  // --------------------------------------------------------------------------
  // 19. Local mutation + outbox are transactional
  // --------------------------------------------------------------------------
  test('progress record and outbox entry are created together', () async {
    final schemeId = await createScheme();

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'initial',
      progressPercentage: 0.0,
      date: DateTime(2026, 8, 1),
    );

    final updates = await progressRepo.watchProgressUpdates().first;
    final outbox = await database
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='progress_update'",
        )
        .get();

    expect(updates, hasLength(1));
    expect(outbox, isNotEmpty);
  });

  // --------------------------------------------------------------------------
  // 20. Completed progress can represent 100%
  // --------------------------------------------------------------------------
  test('completed status with 100% is valid and updates scheme', () async {
    final schemeId = await createScheme();

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'completed',
      progressPercentage: 100.0,
      date: DateTime(2026, 8, 30),
    );

    final updates = await progressRepo.watchProgressUpdates().first;
    expect(updates.single.status, 'completed');
    expect(updates.single.progressPercentage, 100.0);

    final schemes = await schemesRepo.watchSchemes().first;
    expect(schemes.single.status, 'completed');
    expect(schemes.single.progressPercentage, 100.0);
  });

  // --------------------------------------------------------------------------
  // 21. Percentage cannot be below 0
  // --------------------------------------------------------------------------
  test('percentage cannot be below 0 — clamped to 0', () async {
    final schemeId = await createScheme();

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'initial',
      progressPercentage: -5.0,
      date: DateTime(2026, 8, 1),
    );

    final updates = await progressRepo.watchProgressUpdates().first;
    expect(updates.single.progressPercentage, greaterThanOrEqualTo(0.0));
  });

  // --------------------------------------------------------------------------
  // 22. Percentage cannot exceed 100
  // --------------------------------------------------------------------------
  test('percentage cannot exceed 100 — clamped to 100', () async {
    final schemeId = await createScheme();

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'in_progress',
      progressPercentage: 200.0,
      date: DateTime(2026, 8, 1),
    );

    final updates = await progressRepo.watchProgressUpdates().first;
    expect(updates.single.progressPercentage, lessThanOrEqualTo(100.0));
  });

  // --------------------------------------------------------------------------
  // 23. Incomplete status handles incomplete reason correctly
  // --------------------------------------------------------------------------
  test('incomplete reason is null for non-incomplete statuses', () async {
    final schemeId = await createScheme();

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'in_progress',
      progressPercentage: 50.0,
      date: DateTime(2026, 8, 1),
    );

    final updates = await progressRepo.watchProgressUpdates().first;
    expect(updates.single.incompleteReason, isNull);
  });

  test('incomplete reason is stored for incomplete status', () async {
    final schemeId = await createScheme();

    await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'incomplete',
      progressPercentage: 45.0,
      date: DateTime(2026, 8, 1),
      incompleteReason: 'Budget exhausted',
    );

    final updates = await progressRepo.watchProgressUpdates().first;
    expect(updates.single.incompleteReason, 'Budget exhausted');
  });

  // --------------------------------------------------------------------------
  // 24. watchProgressByScheme isolates records
  // --------------------------------------------------------------------------
  test('watchProgressByScheme isolates records by scheme', () async {
    final schemeId1 = await createScheme(code: 'SCH-A');
    final schemeId2 = await createScheme(code: 'SCH-B');

    await progressRepo.createProgress(
      schemeId: schemeId1,
      status: 'working',
      progressPercentage: 20.0,
      date: DateTime(2026, 8, 1),
    );
    await progressRepo.createProgress(
      schemeId: schemeId2,
      status: 'completed',
      progressPercentage: 100.0,
      date: DateTime(2026, 8, 2),
    );

    final s1 = await progressRepo.watchProgressByScheme(schemeId1).first;
    expect(s1, hasLength(1));
    expect(s1.single.schemeId, schemeId1);

    final s2 = await progressRepo.watchProgressByScheme(schemeId2).first;
    expect(s2, hasLength(1));
    expect(s2.single.schemeId, schemeId2);
  });

  // --------------------------------------------------------------------------
  // 25. Deleting last progress reverts scheme to initial
  // --------------------------------------------------------------------------
  test('deleting last progress update reverts scheme to initial', () async {
    final schemeId = await createScheme();

    final id = await progressRepo.createProgress(
      schemeId: schemeId,
      status: 'completed',
      progressPercentage: 100.0,
      date: DateTime(2026, 8, 30),
    );

    await progressRepo.deleteProgress(id);

    final schemes = await schemesRepo.watchSchemes().first;
    expect(schemes.single.status, 'initial');
    expect(schemes.single.progressPercentage, 0.0);
  });
}
