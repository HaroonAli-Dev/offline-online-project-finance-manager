import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/person_summary.dart';
import '../domain/role_definition.dart';

class PeopleRepository {
  PeopleRepository(this._database, this._uuid);

  final AppDatabase _database;
  final Uuid _uuid;

  Stream<List<PersonSummary>> watchPeople({
    String searchQuery = '',
    String? roleCode,
    bool includeInactive = false,
  }) {
    final roleFilter = roleCode ?? '';
    const query = '''
      SELECT
        p.id,
        p.full_name,
        p.phone_number,
        p.email,
        p.address,
        p.notes,
        p.is_active,
        GROUP_CONCAT(pr.role_code, '|') AS role_codes,
        GROUP_CONCAT(r.display_name, '|') AS role_names
      FROM people p
      LEFT JOIN person_roles pr
        ON pr.person_id = p.id
      LEFT JOIN roles r ON r.code = pr.role_code
      WHERE p.deleted_at IS NULL
        AND (? = 1 OR p.is_active = 1)
        AND (
          ? = ''
          OR EXISTS (
            SELECT 1
            FROM person_roles pr_filter
            WHERE pr_filter.person_id = p.id
              AND pr_filter.role_code = ?
          )
        )
        AND (
          LOWER(p.full_name) LIKE LOWER(?)
          OR LOWER(COALESCE(p.phone_number, '')) LIKE LOWER(?)
          OR LOWER(COALESCE(p.email, '')) LIKE LOWER(?)
        )
      GROUP BY p.id
      ORDER BY p.full_name COLLATE NOCASE
    ''';
    final pattern = '%${searchQuery.trim()}%';

    return _database
        .customSelect(
          query,
          variables: [
            Variable.withInt(includeInactive ? 1 : 0),
            Variable.withString(roleFilter),
            Variable.withString(roleFilter),
            Variable.withString(pattern),
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {_database.people, _database.personRoles, _database.roles},
        )
        .watch()
        .map((rows) => rows.map(_personFromRow).toList());
  }

  Stream<List<RoleDefinition>> watchRoles() {
    return (_database.select(
      _database.roles,
    )..orderBy([(role) => OrderingTerm.asc(role.sortOrder)])).watch().map(
      (roles) => roles
          .map(
            (role) =>
                RoleDefinition(code: role.code, displayName: role.displayName),
          )
          .toList(),
    );
  }

  Future<void> createPerson({
    required String fullName,
    required Set<String> roleCodes,
    String? phoneNumber,
    String? email,
    String? address,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc();
    final personId = _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.people)
          .insert(
            PeopleCompanion.insert(
              id: personId,
              fullName: fullName.trim(),
              phoneNumber: Value(_cleanOptional(phoneNumber)),
              email: Value(_cleanOptional(email)),
              address: Value(_cleanOptional(address)),
              notes: Value(_cleanOptional(notes)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _insertRoleAssignments(personId, roleCodes, now);
      await _enqueueChange('person', personId, 'create', now);
    });
  }

  Future<void> updatePerson({
    required String id,
    required String fullName,
    required Set<String> roleCodes,
    String? phoneNumber,
    String? email,
    String? address,
    String? notes,
    bool? isActive,
  }) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.people,
      )..where((person) => person.id.equals(id))).write(
        PeopleCompanion(
          fullName: Value(fullName.trim()),
          phoneNumber: Value(_cleanOptional(phoneNumber)),
          email: Value(_cleanOptional(email)),
          address: Value(_cleanOptional(address)),
          notes: Value(_cleanOptional(notes)),
          isActive: isActive == null ? const Value.absent() : Value(isActive),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _replaceRoleAssignments(id, roleCodes, now);
      await _enqueueChange('person', id, 'update', now);
    });
  }

  Future<void> setPersonActive(String id, {required bool isActive}) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.people,
      )..where((person) => person.id.equals(id))).write(
        PeopleCompanion(
          isActive: Value(isActive),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _enqueueChange('person', id, 'update', now);
    });
  }

  Future<void> deletePerson(String id) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.people,
      )..where((person) => person.id.equals(id))).write(
        PeopleCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pendingDelete.databaseValue),
        ),
      );
      await (_database.delete(
        _database.personRoles,
      )..where((assignment) => assignment.personId.equals(id))).go();
      await _enqueueChange('person', id, 'delete', now);
    });
  }

  Future<void> _insertRoleAssignments(
    String personId,
    Set<String> roleCodes,
    DateTime now,
  ) async {
    for (final roleCode in roleCodes) {
      await _database
          .into(_database.personRoles)
          .insertOnConflictUpdate(
            PersonRolesCompanion.insert(personId: personId, roleCode: roleCode),
          );
      await _enqueueChange(
        'person_role',
        '${personId}_$roleCode',
        'create',
        now,
      );
    }
  }

  Future<void> _replaceRoleAssignments(
    String personId,
    Set<String> roleCodes,
    DateTime now,
  ) async {
    await (_database.delete(
      _database.personRoles,
    )..where((pr) => pr.personId.equals(personId))).go();

    await _insertRoleAssignments(personId, roleCodes, now);
  }

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

  PersonSummary _personFromRow(QueryRow row) {
    List<String> split(String? value) =>
        value == null || value.isEmpty ? const [] : value.split('|');

    return PersonSummary(
      id: row.read<String>('id'),
      fullName: row.read<String>('full_name'),
      phoneNumber: row.readNullable<String>('phone_number'),
      email: row.readNullable<String>('email'),
      address: row.readNullable<String>('address'),
      notes: row.readNullable<String>('notes'),
      isActive: row.read<int>('is_active') == 1,
      roleCodes: split(row.readNullable<String>('role_codes')),
      roleNames: split(row.readNullable<String>('role_names')),
    );
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
