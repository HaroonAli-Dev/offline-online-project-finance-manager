import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/expense_model.dart';

class ExpensesRepository {
  ExpensesRepository(this._database, this._uuid);

  final AppDatabase _database;
  final Uuid _uuid;

  Stream<List<ExpenseModel>> watchExpenses({
    String searchQuery = '',
    String? categoryFilter,
    String? siteFilter,
    String? schemeFilter,
    String? personFilter,
  }) {
    final cleanQuery = searchQuery.trim();
    final cleanCategory = categoryFilter?.trim() ?? '';
    final cleanSite = siteFilter?.trim() ?? '';
    final cleanScheme = schemeFilter?.trim() ?? '';
    final cleanPerson = personFilter?.trim() ?? '';

    const querySql = '''
      SELECT
        e.id,
        e.expense_code,
        e.expense_date,
        e.category,
        e.amount,
        e.purpose,
        e.site_id,
        st.name AS site_name,
        e.scheme_id,
        sc.name AS scheme_name,
        e.person_id,
        p.full_name AS person_name,
        e.remarks,
        e.attachment_path
      FROM expenses e
      LEFT JOIN sites st ON st.id = e.site_id AND st.deleted_at IS NULL
      LEFT JOIN schemes sc ON sc.id = e.scheme_id AND sc.deleted_at IS NULL
      LEFT JOIN people p ON p.id = e.person_id AND p.deleted_at IS NULL
      WHERE e.deleted_at IS NULL
        AND (? = '' OR e.category = ?)
        AND (? = '' OR e.site_id = ?)
        AND (? = '' OR e.scheme_id = ?)
        AND (? = '' OR e.person_id = ?)
        AND (
          ? = ''
          OR LOWER(e.purpose) LIKE LOWER(?)
          OR LOWER(e.expense_code) LIKE LOWER(?)
        )
      ORDER BY e.expense_date DESC, e.created_at DESC
    ''';
    final pattern = '%$cleanQuery%';

    return _database
        .customSelect(
          querySql,
          variables: [
            Variable.withString(cleanCategory),
            Variable.withString(cleanCategory),
            Variable.withString(cleanSite),
            Variable.withString(cleanSite),
            Variable.withString(cleanScheme),
            Variable.withString(cleanScheme),
            Variable.withString(cleanPerson),
            Variable.withString(cleanPerson),
            Variable.withString(cleanQuery),
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {
            _database.expenses,
            _database.sites,
            _database.schemes,
            _database.people,
          },
        )
        .watch()
        .map((rows) => rows.map(_expenseFromRow).toList());
  }

  Future<void> createExpense({
    required String expenseCode,
    required DateTime expenseDate,
    required String category,
    required double amount,
    required String purpose,
    String? siteId,
    String? schemeId,
    String? personId,
    String? remarks,
    String? attachmentPath,
  }) async {
    final now = DateTime.now().toUtc();
    final expenseId = _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: expenseId,
              expenseCode: expenseCode.trim(),
              expenseDate: expenseDate,
              category: category.trim(),
              amount: Value(amount < 0 ? 0 : (amount * 100).round()),
              purpose: purpose.trim(),
              siteId: Value(_cleanOptional(siteId)),
              schemeId: Value(_cleanOptional(schemeId)),
              personId: Value(_cleanOptional(personId)),
              remarks: Value(_cleanOptional(remarks)),
              attachmentPath: Value(_cleanOptional(attachmentPath)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueueChange('expense', expenseId, 'create', now);
    });
  }

  Future<void> updateExpense({
    required String id,
    required String expenseCode,
    required DateTime expenseDate,
    required String category,
    required double amount,
    required String purpose,
    String? siteId,
    String? schemeId,
    String? personId,
    String? remarks,
    String? attachmentPath,
  }) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.expenses,
      )..where((exp) => exp.id.equals(id))).write(
        ExpensesCompanion(
          expenseCode: Value(expenseCode.trim()),
          expenseDate: Value(expenseDate.toUtc()),
          category: Value(category.trim()),
          amount: Value(amount < 0 ? 0 : (amount * 100).round()),
          purpose: Value(purpose.trim()),
          siteId: Value(_cleanOptional(siteId)),
          schemeId: Value(_cleanOptional(schemeId)),
          personId: Value(_cleanOptional(personId)),
          remarks: Value(_cleanOptional(remarks)),
          attachmentPath: Value(_cleanOptional(attachmentPath)),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _enqueueChange('expense', id, 'update', now);
    });
  }

  Future<void> deleteExpense(String id) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.expenses,
      )..where((exp) => exp.id.equals(id))).write(
        ExpensesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pendingDelete.databaseValue),
        ),
      );
      await _enqueueChange('expense', id, 'delete', now);
    });
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

  ExpenseModel _expenseFromRow(QueryRow row) {
    return ExpenseModel(
      id: row.read<String>('id'),
      expenseCode: row.read<String>('expense_code'),
      expenseDate: row.read<DateTime>('expense_date'),
      category: row.read<String>('category'),
      amount: (row.read<int>('amount')) / 100.0,
      purpose: row.read<String>('purpose'),
      siteId: row.readNullable<String>('site_id'),
      siteName: row.readNullable<String>('site_name'),
      schemeId: row.readNullable<String>('scheme_id'),
      schemeName: row.readNullable<String>('scheme_name'),
      personId: row.readNullable<String>('person_id'),
      personName: row.readNullable<String>('person_name'),
      remarks: row.readNullable<String>('remarks'),
      attachmentPath: row.readNullable<String>('attachment_path'),
    );
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
