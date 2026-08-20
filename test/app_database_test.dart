import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';

void main() {
  test('opens the database and executes a health check', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.validateConnection();
  });

  test('migrates from schema version 2 to 3 and seeds Other role', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.customStatement("DELETE FROM roles WHERE code = 'other'");
    await database.customStatement('PRAGMA user_version = 2');

    await database.migration.onUpgrade(database.createMigrator(), 2, 3);

    final roles = await database.select(database.roles).get();
    expect(roles, hasLength(11));
    expect(roles.any((role) => role.code == 'other'), isTrue);
  });

  test('migrates from schema version 3 to 4 creating sites table', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.customStatement('PRAGMA user_version = 3');

    await database.migration.onUpgrade(database.createMigrator(), 3, 4);

    final sites = await database.select(database.sites).get();
    expect(sites, isEmpty);
  });

  test('migrates from schema version 4 to 5 creating schemes table', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.customStatement('PRAGMA user_version = 4');

    await database.migration.onUpgrade(database.createMigrator(), 4, 5);

    final schemes = await database.select(database.schemes).get();
    expect(schemes, isEmpty);
  });

  test(
    'migrates from schema version 5 to 6 creating transactions table',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database.customStatement('PRAGMA user_version = 5');

      await database.migration.onUpgrade(database.createMigrator(), 5, 6);

      final transactions = await database.select(database.transactions).get();
      expect(transactions, isEmpty);
    },
  );

  test('migrates from schema version 6 to 7 creating expenses table', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.customStatement('PRAGMA user_version = 6');

    await database.migration.onUpgrade(database.createMigrator(), 6, 7);

    final expenses = await database.select(database.expenses).get();
    expect(expenses, isEmpty);
  });

  test(
    'migrates from schema version 7 to 8 creating vehicles tables',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database.customStatement('PRAGMA user_version = 7');

      await database.migration.onUpgrade(database.createMigrator(), 7, 8);

      final vehicles = await database.select(database.vehicles).get();
      expect(vehicles, isEmpty);
      final logs = await database.select(database.vehicleLogs).get();
      expect(logs, isEmpty);
    },
  );

  test('migrates from schema version 8 to 9 updating paisa amounts and person_roles', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.customStatement('PRAGMA user_version = 8');

    await database.migration.onUpgrade(database.createMigrator(), 8, 9);

    final personRoles = await database.select(database.personRoles).get();
    expect(personRoles, isEmpty);
  });

  test('migrates from schema version 9 to 10 creating bills table', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.customStatement('PRAGMA user_version = 9');

    await database.migration.onUpgrade(database.createMigrator(), 9, 10);

    final bills = await database.select(database.bills).get();
    expect(bills, isEmpty);
  });

  test(
    'migrates from schema version 10 to 11 creating progress_updates table',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database.customStatement('PRAGMA user_version = 10');

      await database.migration.onUpgrade(database.createMigrator(), 10, 11);

      final updates = await database.select(database.progressUpdates).get();
      expect(updates, isEmpty);
    },
  );

  test(
    'migrates from schema version 11 to 12 creating attachments table',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database.customStatement('PRAGMA user_version = 11');

      await database.migration.onUpgrade(database.createMigrator(), 11, 12);

      final attachments = await database.select(database.attachments).get();
      expect(attachments, isEmpty);
    },
  );

  test(
    'migrates from schema version 12 to 13 creating reminders table',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database.customStatement('PRAGMA user_version = 12');

      await database.migration.onUpgrade(database.createMigrator(), 12, 13);

      final reminders = await database.select(database.reminders).get();
      expect(reminders, isEmpty);
    },
  );

  test(
    'migrates from schema version 13 to 14 adding attachment metadata',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database.migration.onUpgrade(database.createMigrator(), 13, 14);

      final columns = await database
          .customSelect('PRAGMA table_info(attachments)')
          .get();
      final names = columns.map((row) => row.read<String>('name')).toSet();
      expect(names, containsAll(['file_size', 'image_width', 'image_height']));
    },
  );
}
