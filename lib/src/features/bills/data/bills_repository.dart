import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/bill_model.dart';
import '../domain/bill_totals.dart';

class BillsRepository {
  BillsRepository(this._database, this._uuid);

  final AppDatabase _database;
  final Uuid _uuid;

  // ---------------------------------------------------------------------------
  // Watch / Query
  // ---------------------------------------------------------------------------

  Stream<List<BillModel>> watchBills({
    String searchQuery = '',
    String? schemeFilter,
    String? typeFilter,
    String? statusFilter,
  }) {
    final cleanQuery = searchQuery.trim();
    final cleanScheme = schemeFilter?.trim() ?? '';
    final cleanType = typeFilter?.trim() ?? '';
    final cleanStatus = statusFilter?.trim() ?? '';

    const querySql = '''
      SELECT
        b.id,
        b.scheme_id,
        sc.name    AS scheme_name,
        st.name    AS site_name,
        b.bill_type,
        b.bill_number,
        b.bill_date,
        b.amount,
        b.status,
        b.remarks
      FROM bills b
      JOIN schemes sc ON sc.id = b.scheme_id AND sc.deleted_at IS NULL
      LEFT JOIN sites st ON st.id = sc.site_id AND st.deleted_at IS NULL
      WHERE b.deleted_at IS NULL
        AND (? = '' OR b.scheme_id = ?)
        AND (? = '' OR b.bill_type = ?)
        AND (? = '' OR b.status = ?)
        AND (
          ? = ''
          OR LOWER(sc.name)       LIKE LOWER(?)
          OR LOWER(b.bill_number) LIKE LOWER(?)
          OR LOWER(b.remarks)     LIKE LOWER(?)
        )
      ORDER BY b.bill_date DESC, b.created_at DESC
    ''';
    final pattern = '%$cleanQuery%';

    return _database
        .customSelect(
          querySql,
          variables: [
            Variable.withString(cleanScheme),
            Variable.withString(cleanScheme),
            Variable.withString(cleanType),
            Variable.withString(cleanType),
            Variable.withString(cleanStatus),
            Variable.withString(cleanStatus),
            Variable.withString(cleanQuery),
            Variable.withString(pattern),
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {_database.bills, _database.schemes, _database.sites},
        )
        .watch()
        .map((rows) => rows.map(_billFromRow).toList());
  }

  Stream<List<BillModel>> watchBillsByScheme(String schemeId) {
    const querySql = '''
      SELECT
        b.id,
        b.scheme_id,
        sc.name    AS scheme_name,
        st.name    AS site_name,
        b.bill_type,
        b.bill_number,
        b.bill_date,
        b.amount,
        b.status,
        b.remarks
      FROM bills b
      JOIN schemes sc ON sc.id = b.scheme_id AND sc.deleted_at IS NULL
      LEFT JOIN sites st ON st.id = sc.site_id AND st.deleted_at IS NULL
      WHERE b.deleted_at IS NULL
        AND b.scheme_id = ?
      ORDER BY b.bill_date ASC, b.created_at ASC
    ''';

    return _database
        .customSelect(
          querySql,
          variables: [Variable.withString(schemeId)],
          readsFrom: {_database.bills, _database.schemes, _database.sites},
        )
        .watch()
        .map((rows) => rows.map(_billFromRow).toList());
  }

  Future<BillTotals> getBillTotals(String schemeId) async {
    const sql = '''
      SELECT
        COALESCE(SUM(amount), 0)                              AS total_billed,
        COALESCE(SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END), 0) AS total_paid
      FROM bills
      WHERE deleted_at IS NULL
        AND scheme_id = ?
    ''';

    final row = await _database
        .customSelect(sql, variables: [Variable.withString(schemeId)])
        .getSingle();

    return BillTotals(
      totalBilled: row.read<int>('total_billed') / 100.0,
      totalPaid: row.read<int>('total_paid') / 100.0,
    );
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Creates a bill locally and returns its stable UUID.
  ///
  /// Callers can use the returned ID immediately to link generic attachments
  /// while the bill and its outbox entry remain safely offline.
  Future<String> createBill({
    required String schemeId,
    required String billType,
    String? billNumber,
    required DateTime billDate,
    required double amount,
    String status = 'draft',
    String? remarks,
  }) async {
    final now = DateTime.now().toUtc();
    final billId = _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.bills)
          .insert(
            BillsCompanion.insert(
              id: billId,
              schemeId: schemeId,
              billType: billType.trim(),
              billNumber: Value(_cleanOptional(billNumber)),
              billDate: billDate.toUtc(),
              amount: Value(amount < 0 ? 0 : (amount * 100).round()),
              status: Value(status.trim().isEmpty ? 'draft' : status.trim()),
              remarks: Value(_cleanOptional(remarks)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueueChange('bill', billId, 'create', now);
    });
    return billId;
  }

  Future<void> updateBill({
    required String id,
    required String schemeId,
    required String billType,
    String? billNumber,
    required DateTime billDate,
    required double amount,
    required String status,
    String? remarks,
  }) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.bills,
      )..where((b) => b.id.equals(id))).write(
        BillsCompanion(
          schemeId: Value(schemeId),
          billType: Value(billType.trim()),
          billNumber: Value(_cleanOptional(billNumber)),
          billDate: Value(billDate.toUtc()),
          amount: Value(amount < 0 ? 0 : (amount * 100).round()),
          status: Value(status.trim()),
          remarks: Value(_cleanOptional(remarks)),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _enqueueChange('bill', id, 'update', now);
    });
  }

  Future<void> deleteBill(String id) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.bills,
      )..where((b) => b.id.equals(id))).write(
        BillsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pendingDelete.databaseValue),
        ),
      );
      await _enqueueChange('bill', id, 'delete', now);
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  BillModel _billFromRow(QueryRow row) {
    return BillModel(
      id: row.read<String>('id'),
      schemeId: row.read<String>('scheme_id'),
      schemeName: row.read<String>('scheme_name'),
      siteName: row.readNullable<String>('site_name'),
      billType: row.read<String>('bill_type'),
      billNumber: row.readNullable<String>('bill_number'),
      billDate: row.read<DateTime>('bill_date'),
      amount: row.read<int>('amount') / 100.0,
      status: row.read<String>('status'),
      remarks: row.readNullable<String>('remarks'),
    );
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
