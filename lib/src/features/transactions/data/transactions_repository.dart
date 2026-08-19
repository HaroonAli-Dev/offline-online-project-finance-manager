import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/transaction_model.dart';

class TransactionsRepository {
  TransactionsRepository(this._database, this._uuid);

  final AppDatabase _database;
  final Uuid _uuid;

  Stream<List<TransactionModel>> watchTransactions({
    String searchQuery = '',
    String? typeFilter,
    String? personFilter,
    String? schemeFilter,
    String? siteFilter,
  }) {
    final cleanQuery = searchQuery.trim();
    final cleanType = typeFilter?.trim() ?? '';
    final cleanPerson = personFilter?.trim() ?? '';
    final cleanScheme = schemeFilter?.trim() ?? '';
    final cleanSite = siteFilter?.trim() ?? '';

    const querySql = '''
      SELECT
        t.id,
        t.transaction_code,
        t.transaction_date,
        t.type,
        t.person_id,
        p.full_name AS person_name,
        t.amount,
        t.quantity,
        t.purpose,
        t.payment_method,
        t.reference_number,
        t.remarks,
        t.scheme_id,
        sc.name AS scheme_name,
        t.site_id,
        st.name AS site_name
      FROM transactions t
      LEFT JOIN people p ON p.id = t.person_id AND p.deleted_at IS NULL
      LEFT JOIN schemes sc ON sc.id = t.scheme_id AND sc.deleted_at IS NULL
      LEFT JOIN sites st ON st.id = t.site_id AND st.deleted_at IS NULL
      WHERE t.deleted_at IS NULL
        AND (? = '' OR t.type = ?)
        AND (? = '' OR t.person_id = ?)
        AND (? = '' OR t.scheme_id = ?)
        AND (? = '' OR t.site_id = ?)
        AND (
          ? = ''
          OR LOWER(t.purpose) LIKE LOWER(?)
          OR LOWER(t.transaction_code) LIKE LOWER(?)
          OR LOWER(COALESCE(t.reference_number, '')) LIKE LOWER(?)
        )
      ORDER BY t.transaction_date DESC, t.created_at DESC
    ''';
    final pattern = '%$cleanQuery%';

    return _database
        .customSelect(
          querySql,
          variables: [
            Variable.withString(cleanType),
            Variable.withString(cleanType),
            Variable.withString(cleanPerson),
            Variable.withString(cleanPerson),
            Variable.withString(cleanScheme),
            Variable.withString(cleanScheme),
            Variable.withString(cleanSite),
            Variable.withString(cleanSite),
            Variable.withString(cleanQuery),
            Variable.withString(pattern),
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {
            _database.transactions,
            _database.people,
            _database.schemes,
            _database.sites,
          },
        )
        .watch()
        .map((rows) => rows.map(_transactionFromRow).toList());
  }

  Future<void> createTransaction({
    required String transactionCode,
    required DateTime transactionDate,
    required String type,
    String? personId,
    required double amount,
    double? quantity,
    required String purpose,
    String paymentMethod = 'cash',
    String? referenceNumber,
    String? remarks,
    String? schemeId,
    String? siteId,
  }) async {
    final now = DateTime.now().toUtc();
    final txnId = _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: txnId,
              transactionCode: transactionCode.trim(),
              transactionDate: transactionDate,
              type: type.trim(),
              personId: Value(_cleanOptional(personId)),
              amount: Value(amount < 0 ? 0 : (amount * 100).round()),
              quantity: Value(quantity),
              purpose: purpose.trim(),
              paymentMethod: Value(
                paymentMethod.trim().isEmpty ? 'cash' : paymentMethod.trim(),
              ),
              referenceNumber: Value(_cleanOptional(referenceNumber)),
              remarks: Value(_cleanOptional(remarks)),
              schemeId: Value(_cleanOptional(schemeId)),
              siteId: Value(_cleanOptional(siteId)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueueChange('transaction', txnId, 'create', now);
    });
  }

  Future<void> updateTransaction({
    required String id,
    required String transactionCode,
    required DateTime transactionDate,
    required String type,
    String? personId,
    required double amount,
    double? quantity,
    required String purpose,
    required String paymentMethod,
    String? referenceNumber,
    String? remarks,
    String? schemeId,
    String? siteId,
  }) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.transactions,
      )..where((txn) => txn.id.equals(id))).write(
        TransactionsCompanion(
          transactionCode: Value(transactionCode.trim()),
          transactionDate: Value(transactionDate.toUtc()),
          type: Value(type.trim()),
          personId: Value(_cleanOptional(personId)),
          amount: Value(amount < 0 ? 0 : (amount * 100).round()),
          quantity: Value(quantity),
          purpose: Value(purpose.trim()),
          paymentMethod: Value(paymentMethod.trim()),
          referenceNumber: Value(_cleanOptional(referenceNumber)),
          remarks: Value(_cleanOptional(remarks)),
          schemeId: Value(_cleanOptional(schemeId)),
          siteId: Value(_cleanOptional(siteId)),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _enqueueChange('transaction', id, 'update', now);
    });
  }

  Future<void> deleteTransaction(String id) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.transactions,
      )..where((txn) => txn.id.equals(id))).write(
        TransactionsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pendingDelete.databaseValue),
        ),
      );
      await _enqueueChange('transaction', id, 'delete', now);
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

  TransactionModel _transactionFromRow(QueryRow row) {
    return TransactionModel(
      id: row.read<String>('id'),
      transactionCode: row.read<String>('transaction_code'),
      transactionDate: row.read<DateTime>('transaction_date'),
      type: row.read<String>('type'),
      personId: row.readNullable<String>('person_id'),
      personName: row.readNullable<String>('person_name'),
      amount: (row.read<int>('amount')) / 100.0,
      quantity: row.readNullable<double>('quantity'),
      purpose: row.read<String>('purpose'),
      paymentMethod: row.read<String>('payment_method'),
      referenceNumber: row.readNullable<String>('reference_number'),
      remarks: row.readNullable<String>('remarks'),
      schemeId: row.readNullable<String>('scheme_id'),
      schemeName: row.readNullable<String>('scheme_name'),
      siteId: row.readNullable<String>('site_id'),
      siteName: row.readNullable<String>('site_name'),
    );
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
