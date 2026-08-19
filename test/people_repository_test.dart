import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';
import 'package:offline_finance_management_app/src/features/people/data/people_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late PeopleRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = PeopleRepository(database, const Uuid());
  });

  tearDown(() => database.close());

  test('seeds default roles including Other', () async {
    await database.validateConnection();
    final roles = await repository.watchRoles().first;
    expect(roles, hasLength(11));
    expect(
      roles.map((role) => role.code),
      containsAll([
        'sdo',
        'engineer',
        'xen',
        'peon',
        'do',
        'accountant',
        'clerk',
        'driver',
        'labour',
        'security',
        'other',
      ]),
    );
  });

  test(
    'creates, updates, searches, and soft-deletes a person offline',
    () async {
      await repository.createPerson(
        fullName: 'Ayesha Khan',
        roleCodes: {'engineer'},
        phoneNumber: '0300 1234567',
      );
      var people = await repository.watchPeople(searchQuery: 'ayesha').first;
      expect(people, hasLength(1));
      expect(people.single.roleNames, ['Engineer']);

      await repository.updatePerson(
        id: people.single.id,
        fullName: 'Ayesha Khan',
        roleCodes: {'engineer', 'sdo'},
        phoneNumber: '0300 7654321',
      );
      people = await repository.watchPeople(searchQuery: '7654').first;
      expect(people.single.roleCodes, containsAll(['engineer', 'sdo']));

      await repository.deletePerson(people.single.id);
      expect(await repository.watchPeople().first, isEmpty);
    },
  );

  test('filters people by role', () async {
    await repository.createPerson(
      fullName: 'Ali Driver',
      roleCodes: {'driver'},
    );
    await repository.createPerson(
      fullName: 'Sara Engineer',
      roleCodes: {'engineer'},
    );

    final drivers = await repository.watchPeople(roleCode: 'driver').first;
    expect(drivers, hasLength(1));
    expect(drivers.single.fullName, 'Ali Driver');

    final engineers = await repository.watchPeople(roleCode: 'engineer').first;
    expect(engineers, hasLength(1));
    expect(engineers.single.fullName, 'Sara Engineer');
  });

  test('deactivates and reactivates a person', () async {
    await repository.createPerson(
      fullName: 'Inactive Staff',
      roleCodes: {'clerk'},
    );
    final person = (await repository.watchPeople().first).single;

    await repository.setPersonActive(person.id, isActive: false);
    expect(await repository.watchPeople().first, isEmpty);

    final inactive = await repository.watchPeople(includeInactive: true).first;
    expect(inactive, hasLength(1));
    expect(inactive.single.isActive, isFalse);

    await repository.setPersonActive(person.id, isActive: true);
    final active = await repository.watchPeople().first;
    expect(active, hasLength(1));
    expect(active.single.isActive, isTrue);
  });
}
