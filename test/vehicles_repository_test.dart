import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';
import 'package:offline_finance_management_app/src/features/people/data/people_repository.dart';
import 'package:offline_finance_management_app/src/features/sites/data/sites_repository.dart';
import 'package:offline_finance_management_app/src/features/vehicles/data/vehicles_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late PeopleRepository peopleRepository;
  late SitesRepository sitesRepository;
  late VehiclesRepository vehiclesRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    peopleRepository = PeopleRepository(database, uuid);
    sitesRepository = SitesRepository(database, uuid);
    vehiclesRepository = VehiclesRepository(database, uuid);
  });

  tearDown(() => database.close());

  test(
    'creates, updates, searches, logs fuel, and soft-deletes vehicles offline',
    () async {
      await sitesRepository.createSite(name: 'Bypass Quarry Site');
      final site = (await sitesRepository.watchSites().first).single;

      await peopleRepository.createPerson(
        fullName: 'Driver Tariq',
        roleCodes: {'driver'},
      );
      final driver = (await peopleRepository.watchPeople().first).single;

      await vehiclesRepository.createVehicle(
        vehicleNumber: 'LEB-7788',
        makeModel: 'Hino Dumper 2024',
        vehicleType: 'dumper',
        assignedSiteId: site.id,
        assignedDriverId: driver.id,
        status: 'active',
        remarks: 'Primary quarry dumper',
      );

      var vehicles = await vehiclesRepository
          .watchVehicles(searchQuery: '7788')
          .first;
      expect(vehicles, hasLength(1));
      expect(vehicles.single.vehicleNumber, 'LEB-7788');
      expect(vehicles.single.assignedDriverName, 'Driver Tariq');
      expect(vehicles.single.assignedSiteName, 'Bypass Quarry Site');

      await vehiclesRepository.addVehicleLog(
        vehicleId: vehicles.single.id,
        logDate: DateTime(2026, 3, 12),
        logType: 'fuel',
        amount: 15000.0,
        quantityLiters: 50.0,
        driverId: driver.id,
        siteId: site.id,
        description: 'Diesel Tank Refill 50L',
      );

      final logs = await vehiclesRepository
          .watchVehicleLogs(vehicles.single.id)
          .first;
      expect(logs, hasLength(1));
      expect(logs.single.logType, 'fuel');
      expect(logs.single.amount, 15000.0);
      expect(logs.single.quantityLiters, 50.0);

      await vehiclesRepository.updateVehicle(
        id: vehicles.single.id,
        vehicleNumber: 'LEB-7788',
        makeModel: 'Hino Dumper 2024 Revised',
        vehicleType: 'dumper',
        assignedSiteId: site.id,
        assignedDriverId: driver.id,
        status: 'under_maintenance',
      );

      vehicles = await vehiclesRepository.watchVehicles().first;
      expect(vehicles.single.status, 'under_maintenance');

      await vehiclesRepository.deleteVehicle(vehicles.single.id);
      expect(await vehiclesRepository.watchVehicles().first, isEmpty);
    },
  );
}
