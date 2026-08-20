import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/sync_outbox.dart';
import 'tables/people.dart';
import 'tables/person_roles.dart';
import 'tables/roles.dart';
import 'tables/sites.dart';
import 'tables/schemes.dart';
import 'tables/transactions.dart';
import 'tables/expenses.dart';
import 'tables/vehicles.dart';
import 'tables/vehicle_logs.dart';
import 'tables/bills.dart';
import 'tables/progress_updates.dart';
import 'tables/attachments.dart';
import 'tables/reminder_entity_links.dart';
import 'tables/reminders.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    SyncOutbox,
    Roles,
    People,
    PersonRoles,
    Sites,
    Schemes,
    Transactions,
    Expenses,
    Vehicles,
    VehicleLogs,
    Bills,
    ProgressUpdates,
    Attachments,
    Reminders,
    ReminderEntityLinks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'finance_construction',
              native: const DriftNativeOptions(shareAcrossIsolates: true),
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await seedDefaultRoles();
      await _createPeopleIndexes();
      await _createSitesIndexes();
      await _createSchemesIndexes();
      await _createTransactionsIndexes();
      await _createExpensesIndexes();
      await _createVehiclesIndexes();
      await _createBillsIndexes();
      await _createProgressUpdatesIndexes();
      await _createAttachmentsIndexes();
      await _createRemindersIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(roles);
        await migrator.createTable(people);
        await migrator.createTable(personRoles);
        await seedDefaultRoles();
        await _createPeopleIndexes();
      }
      if (from < 3) {
        await seedDefaultRoles();
      }
      if (from < 4) {
        await migrator.createTable(sites);
        await _createSitesIndexes();
      }
      if (from < 5) {
        await migrator.createTable(schemes);
        await _createSchemesIndexes();
      }
      if (from < 6) {
        await migrator.createTable(transactions);
        await _createTransactionsIndexes();
      }
      if (from < 7) {
        await migrator.createTable(expenses);
        await _createExpensesIndexes();
      }
      if (from < 8) {
        await migrator.createTable(vehicles);
        await migrator.createTable(vehicleLogs);
        await _createVehiclesIndexes();
      }
      if (from < 9) {
        await customStatement('''
          CREATE TEMP TABLE person_roles_temp AS SELECT DISTINCT person_id, role_code FROM person_roles;
        ''');
        await customStatement('DROP TABLE person_roles;');
        await migrator.createTable(personRoles);
        await customStatement('''
          INSERT OR IGNORE INTO person_roles (person_id, role_code)
          SELECT person_id, role_code FROM person_roles_temp;
        ''');
        await customStatement('DROP TABLE person_roles_temp;');

        await customStatement(
          'UPDATE expenses SET amount = CAST(ROUND(amount * 100) AS INTEGER);',
        );
        await customStatement(
          'UPDATE transactions SET amount = CAST(ROUND(amount * 100) AS INTEGER);',
        );
        await customStatement(
          'UPDATE schemes SET budget = CAST(ROUND(budget * 100) AS INTEGER);',
        );
        await customStatement(
          'UPDATE vehicle_logs SET amount = CAST(ROUND(amount * 100) AS INTEGER);',
        );
      }
      if (from < 10) {
        await migrator.createTable(bills);
        await _createBillsIndexes();
      }
      if (from < 11) {
        await migrator.createTable(progressUpdates);
        await _createProgressUpdatesIndexes();
      }
      if (from < 12) {
        await migrator.createTable(attachments);
        await _createAttachmentsIndexes();
      }
      if (from < 13) {
        await migrator.createTable(reminders);
        await _createRemindersIndexes();
      }
      if (from < 14) {
        await _addAttachmentMetadataColumns(migrator);
      }
      if (from < 15) {
        await migrator.createTable(reminderEntityLinks);
        await _createReminderEntityLinkIndexes();
      }
    },
  );

  Future<void> validateConnection() async {
    await customSelect('SELECT 1 AS health_check').getSingle();
  }

  Future<void> _addAttachmentMetadataColumns(Migrator migrator) async {
    final columns = await customSelect('PRAGMA table_info(attachments)').get();
    final names = columns.map((row) => row.read<String>('name')).toSet();
    if (!names.contains('file_size')) {
      await migrator.addColumn(
        attachments,
        attachments.fileSize as GeneratedColumn<Object>,
      );
    }
    if (!names.contains('image_width')) {
      await migrator.addColumn(
        attachments,
        attachments.imageWidth as GeneratedColumn<Object>,
      );
    }
    if (!names.contains('image_height')) {
      await migrator.addColumn(
        attachments,
        attachments.imageHeight as GeneratedColumn<Object>,
      );
    }
  }

  Future<void> seedDefaultRoles() async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(roles, [
        RolesCompanion.insert(code: 'sdo', displayName: 'SDO', sortOrder: 10),
        RolesCompanion.insert(
          code: 'engineer',
          displayName: 'Engineer',
          sortOrder: 20,
        ),
        RolesCompanion.insert(code: 'xen', displayName: 'XEN', sortOrder: 30),
        RolesCompanion.insert(code: 'peon', displayName: 'Peon', sortOrder: 40),
        RolesCompanion.insert(code: 'do', displayName: 'DO', sortOrder: 50),
        RolesCompanion.insert(
          code: 'accountant',
          displayName: 'Accountant',
          sortOrder: 60,
        ),
        RolesCompanion.insert(
          code: 'clerk',
          displayName: 'Clerk',
          sortOrder: 70,
        ),
        RolesCompanion.insert(
          code: 'driver',
          displayName: 'Driver',
          sortOrder: 80,
        ),
        RolesCompanion.insert(
          code: 'labour',
          displayName: 'Labour',
          sortOrder: 90,
        ),
        RolesCompanion.insert(
          code: 'security',
          displayName: 'Security',
          sortOrder: 100,
        ),
        RolesCompanion.insert(
          code: 'other',
          displayName: 'Other',
          sortOrder: 110,
        ),
      ]);
    });
  }

  Future<void> _createPeopleIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS people_full_name_index '
      'ON people (full_name COLLATE NOCASE)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS people_phone_number_index '
      'ON people (phone_number)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS people_deleted_at_index '
      'ON people (deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS person_roles_person_id_index '
      'ON person_roles (person_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS person_roles_role_code_index '
      'ON person_roles (role_code)',
    );
  }

  Future<void> _createSitesIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS sites_name_index '
      'ON sites (name COLLATE NOCASE)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS sites_status_index '
      'ON sites (status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS sites_deleted_at_index '
      'ON sites (deleted_at)',
    );
  }

  Future<void> _createSchemesIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS schemes_code_index '
      'ON schemes (scheme_code COLLATE NOCASE)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS schemes_name_index '
      'ON schemes (name COLLATE NOCASE)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS schemes_site_id_index '
      'ON schemes (site_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS schemes_engineer_id_index '
      'ON schemes (engineer_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS schemes_status_index '
      'ON schemes (status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS schemes_deleted_at_index '
      'ON schemes (deleted_at)',
    );
  }

  Future<void> _createTransactionsIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS transactions_code_index '
      'ON transactions (transaction_code COLLATE NOCASE)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS transactions_date_index '
      'ON transactions (transaction_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS transactions_type_index '
      'ON transactions (type)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS transactions_person_id_index '
      'ON transactions (person_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS transactions_scheme_id_index '
      'ON transactions (scheme_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS transactions_site_id_index '
      'ON transactions (site_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS transactions_deleted_at_index '
      'ON transactions (deleted_at)',
    );
  }

  Future<void> _createExpensesIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS expenses_code_index '
      'ON expenses (expense_code COLLATE NOCASE)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS expenses_date_index '
      'ON expenses (expense_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS expenses_category_index '
      'ON expenses (category)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS expenses_site_id_index '
      'ON expenses (site_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS expenses_scheme_id_index '
      'ON expenses (scheme_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS expenses_person_id_index '
      'ON expenses (person_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS expenses_deleted_at_index '
      'ON expenses (deleted_at)',
    );
  }

  Future<void> _createVehiclesIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS vehicles_number_index '
      'ON vehicles (vehicle_number COLLATE NOCASE)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS vehicles_assigned_site_id_index '
      'ON vehicles (assigned_site_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS vehicles_assigned_driver_id_index '
      'ON vehicles (assigned_driver_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS vehicles_deleted_at_index '
      'ON vehicles (deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS vehicle_logs_vehicle_id_index '
      'ON vehicle_logs (vehicle_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS vehicle_logs_log_date_index '
      'ON vehicle_logs (log_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS vehicle_logs_deleted_at_index '
      'ON vehicle_logs (deleted_at)',
    );
  }

  Future<void> _createBillsIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS bills_scheme_id_index '
      'ON bills (scheme_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS bills_bill_type_index '
      'ON bills (bill_type)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS bills_status_index '
      'ON bills (status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS bills_bill_date_index '
      'ON bills (bill_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS bills_deleted_at_index '
      'ON bills (deleted_at)',
    );
  }

  Future<void> _createProgressUpdatesIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS progress_updates_scheme_id_index '
      'ON progress_updates (scheme_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS progress_updates_site_id_index '
      'ON progress_updates (site_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS progress_updates_status_index '
      'ON progress_updates (status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS progress_updates_date_index '
      'ON progress_updates (date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS progress_updates_deleted_at_index '
      'ON progress_updates (deleted_at)',
    );
  }

  Future<void> _createAttachmentsIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS attachments_entity_index '
      'ON attachments (entity_type, entity_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS attachments_category_index '
      'ON attachments (category)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS attachments_deleted_at_index '
      'ON attachments (deleted_at)',
    );
  }

  Future<void> _createRemindersIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS reminders_due_at_index '
      'ON reminders (due_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS reminders_is_done_index '
      'ON reminders (is_done)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS reminders_priority_index '
      'ON reminders (priority)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS reminders_scheme_id_index '
      'ON reminders (scheme_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS reminders_site_id_index '
      'ON reminders (site_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS reminders_deleted_at_index '
      'ON reminders (deleted_at)',
    );
  }

  Future<void> _createReminderEntityLinkIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS reminder_entity_links_reminder_id_index '
      'ON reminder_entity_links (reminder_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS reminder_entity_links_entity_index '
      'ON reminder_entity_links (entity_type, entity_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS reminder_entity_links_deleted_at_index '
      'ON reminder_entity_links (deleted_at)',
    );
  }
}
