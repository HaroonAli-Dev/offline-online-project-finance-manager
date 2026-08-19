import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';
import 'package:offline_finance_management_app/src/features/sites/data/sites_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late SitesRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = SitesRepository(database, const Uuid());
  });

  tearDown(() => database.close());

  test('creates, updates, searches, and soft-deletes a site offline', () async {
    await repository.createSite(
      name: 'Ring Road Bypass Segment A',
      roadInfo: 'KM 10 - KM 25',
      latitude: 31.5204,
      longitude: 74.3587,
      status: 'active',
      notes: 'Initial grading ongoing',
    );

    var sites = await repository.watchSites(searchQuery: 'bypass').first;
    expect(sites, hasLength(1));
    expect(sites.single.name, 'Ring Road Bypass Segment A');
    expect(sites.single.roadInfo, 'KM 10 - KM 25');
    expect(sites.single.latitude, 31.5204);

    await repository.updateSite(
      id: sites.single.id,
      name: 'Ring Road Bypass Segment A Extension',
      roadInfo: 'KM 10 - KM 30',
      latitude: 31.5204,
      longitude: 74.3587,
      status: 'completed',
    );

    sites = await repository.watchSites(searchQuery: 'Extension').first;
    expect(sites, hasLength(1));
    expect(sites.single.status, 'completed');

    await repository.deleteSite(sites.single.id);
    expect(await repository.watchSites().first, isEmpty);
  });

  test('filters sites by status', () async {
    await repository.createSite(name: 'Site Alpha', status: 'active');
    await repository.createSite(name: 'Site Beta', status: 'completed');

    final activeSites = await repository
        .watchSites(statusFilter: 'active')
        .first;
    expect(activeSites, hasLength(1));
    expect(activeSites.single.name, 'Site Alpha');

    final completedSites = await repository
        .watchSites(statusFilter: 'completed')
        .first;
    expect(completedSites, hasLength(1));
    expect(completedSites.single.name, 'Site Beta');
  });
}
