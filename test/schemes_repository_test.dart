import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';
import 'package:offline_finance_management_app/src/features/people/data/people_repository.dart';
import 'package:offline_finance_management_app/src/features/sites/data/sites_repository.dart';
import 'package:offline_finance_management_app/src/features/schemes/data/schemes_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late PeopleRepository peopleRepository;
  late SitesRepository sitesRepository;
  late SchemesRepository schemesRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    peopleRepository = PeopleRepository(database, uuid);
    sitesRepository = SitesRepository(database, uuid);
    schemesRepository = SchemesRepository(database, uuid);
  });

  tearDown(() => database.close());

  test(
    'creates, updates, searches, and soft-deletes a scheme offline',
    () async {
      await sitesRepository.createSite(name: 'GT Road Segment 1');
      final site = (await sitesRepository.watchSites().first).single;

      await peopleRepository.createPerson(
        fullName: 'Engr. Haroon',
        roleCodes: {'engineer'},
      );
      final engineer = (await peopleRepository.watchPeople().first).single;

      await schemesRepository.createScheme(
        schemeCode: 'SCH-101',
        name: 'Dual Carriageway Upgrade',
        siteId: site.id,
        budget: 1500000.0,
        engineerId: engineer.id,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        status: 'working',
        progressPercentage: 25.0,
        description: 'Widening of GT road segment 1',
      );

      var schemes = await schemesRepository
          .watchSchemes(searchQuery: 'Carriageway')
          .first;
      expect(schemes, hasLength(1));
      expect(schemes.single.schemeCode, 'SCH-101');
      expect(schemes.single.siteName, 'GT Road Segment 1');
      expect(schemes.single.engineerName, 'Engr. Haroon');
      expect(schemes.single.budget, 1500000.0);
      expect(schemes.single.progressPercentage, 25.0);

      await schemesRepository.updateScheme(
        id: schemes.single.id,
        schemeCode: 'SCH-101-REV',
        name: 'Dual Carriageway Upgrade Phase 1',
        siteId: site.id,
        budget: 1800000.0,
        engineerId: engineer.id,
        status: 'completed',
        progressPercentage: 100.0,
      );

      schemes = await schemesRepository
          .watchSchemes(searchQuery: 'Phase 1')
          .first;
      expect(schemes.single.schemeCode, 'SCH-101-REV');
      expect(schemes.single.status, 'completed');
      expect(schemes.single.progressPercentage, 100.0);

      await schemesRepository.deleteScheme(schemes.single.id);
      expect(await schemesRepository.watchSchemes().first, isEmpty);
    },
  );

  test('filters schemes by status', () async {
    await schemesRepository.createScheme(
      schemeCode: 'SCH-A',
      name: 'Scheme Alpha',
      budget: 1000.0,
      status: 'initial',
    );
    await schemesRepository.createScheme(
      schemeCode: 'SCH-B',
      name: 'Scheme Beta',
      budget: 2000.0,
      status: 'completed',
    );

    final initialSchemes = await schemesRepository
        .watchSchemes(statusFilter: 'initial')
        .first;
    expect(initialSchemes, hasLength(1));
    expect(initialSchemes.single.name, 'Scheme Alpha');

    final completedSchemes = await schemesRepository
        .watchSchemes(statusFilter: 'completed')
        .first;
    expect(completedSchemes, hasLength(1));
    expect(completedSchemes.single.name, 'Scheme Beta');
  });
}
