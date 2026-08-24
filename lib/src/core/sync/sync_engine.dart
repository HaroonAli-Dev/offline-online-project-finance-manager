import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/documents/data/attachment_file_helper.dart';
import '../../features/documents/data/attachment_storage_service.dart';
import '../database/app_database.dart';

/// Represents the overall status of the background synchronization engine.
enum SyncEngineState {
  idle,
  syncing,
  success,
  failed,
  offline,
}

/// Rich snapshot of the current synchronization state and metrics.
class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    this.state = SyncEngineState.idle,
    this.lastSyncedAt,
    this.pendingOutboxCount = 0,
    this.lastError,
  });

  final SyncEngineState state;
  final DateTime? lastSyncedAt;
  final int pendingOutboxCount;
  final String? lastError;

  SyncStatusSnapshot copyWith({
    SyncEngineState? state,
    DateTime? Function()? lastSyncedAt,
    int? pendingOutboxCount,
    String? Function()? lastError,
  }) {
    return SyncStatusSnapshot(
      state: state ?? this.state,
      lastSyncedAt:
          lastSyncedAt != null ? lastSyncedAt() : this.lastSyncedAt,
      pendingOutboxCount: pendingOutboxCount ?? this.pendingOutboxCount,
      lastError: lastError != null ? lastError() : this.lastError,
    );
  }
}

/// Abstract contract for remote data exchange with Supabase PostgreSQL.
/// Allows clean unit testing without a live backend connection.
abstract class RemoteSyncClient {
  Future<void> upsertRecord({
    required String table,
    required Map<String, dynamic> record,
  });

  Future<void> updateRecord({
    required String table,
    required String id,
    required Map<String, dynamic> updates,
  });

  Future<List<Map<String, dynamic>>> fetchUpdatedSince({
    required String table,
    required String userId,
    DateTime? since,
  });
}

/// Default production implementation of [RemoteSyncClient] using `supabase_flutter`.
class SupabaseRemoteSyncClient implements RemoteSyncClient {
  const SupabaseRemoteSyncClient(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upsertRecord({
    required String table,
    required Map<String, dynamic> record,
  }) async {
    await _client.from(table).upsert(record);
  }

  @override
  Future<void> updateRecord({
    required String table,
    required String id,
    required Map<String, dynamic> updates,
  }) async {
    await _client.from(table).update(updates).eq('id', id);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchUpdatedSince({
    required String table,
    required String userId,
    DateTime? since,
  }) async {
    var query = _client.from(table).select().eq('user_id', userId);
    if (since != null) {
      query = query.gt('updated_at', since.toUtc().toIso8601String());
    }
    final response = await query.order('updated_at', ascending: true);
    return (response as List).cast<Map<String, dynamic>>();
  }
}

/// Offline-first bidirectional synchronization engine for Drift + Supabase.
class SyncEngine {
  SyncEngine({
    required this.database,
    this.remoteClient,
    this.storageClient,
  });

  final AppDatabase database;
  RemoteSyncClient? remoteClient;
  AttachmentStorageClient? storageClient;

  bool _isSyncing = false;
  SyncStatusSnapshot _status = const SyncStatusSnapshot();
  final _statusController = StreamController<SyncStatusSnapshot>.broadcast();

  Stream<SyncStatusSnapshot> get statusStream => _statusController.stream;
  SyncStatusSnapshot get status => _status;

  void setRemoteClient(RemoteSyncClient? client) {
    remoteClient = client;
  }

  void setStorageClient(AttachmentStorageClient? client) {
    storageClient = client;
  }

  void _updateStatus(SyncStatusSnapshot newStatus) {
    _status = newStatus;
    _statusController.add(_status);
  }

  /// Synchronizes local outbox changes and pulls remote updates for [userId].
  ///
  /// Safe to call on all platforms:
  /// - If [userId] is null/empty or [remoteClient] is unconfigured, sync is skipped.
  /// - If network or server is unreachable, backoff is updated on outbox entries without crashing.
  Future<bool> sync({
    required String? userId,
  }) async {
    if (userId == null || userId.trim().isEmpty) {
      _updateStatus(_status.copyWith(
        state: SyncEngineState.idle,
        lastError: () => null,
      ));
      return false;
    }

    final client = remoteClient;
    if (client == null) {
      _updateStatus(_status.copyWith(
        state: SyncEngineState.offline,
      ));
      return false;
    }

    if (_isSyncing) return false;
    _isSyncing = true;
    _updateStatus(_status.copyWith(state: SyncEngineState.syncing));

    try {
      // 1. Push pending local mutations from SyncOutbox
      await _processOutbox(userId: userId, client: client);

      // 2. Pull remote changes incrementally
      await _pullRemoteChanges(userId: userId, client: client);

      final pendingCount = await _getPendingOutboxCount();
      final now = DateTime.now().toUtc();
      _updateStatus(_status.copyWith(
        state: SyncEngineState.success,
        lastSyncedAt: () => now,
        pendingOutboxCount: pendingCount,
        lastError: () => null,
      ));
      return true;
    } catch (e, st) {
      debugPrint('SyncEngine: Error during sync: $e\n$st');
      final pendingCount = await _getPendingOutboxCount();
      _updateStatus(_status.copyWith(
        state: SyncEngineState.failed,
        pendingOutboxCount: pendingCount,
        lastError: () => e.toString().replaceAll(RegExp(r'^Exception: '), ''),
      ));
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<int> _getPendingOutboxCount() async {
    final count = await database.syncOutbox.count().getSingle();
    return count;
  }

  /// Step 1: Process SyncOutbox items in FIFO order with exponential backoff.
  Future<void> _processOutbox({
    required String userId,
    required RemoteSyncClient client,
  }) async {
    final now = DateTime.now().toUtc();
    final pendingEntries = await (database.select(database.syncOutbox)
          ..where((t) =>
              t.nextAttemptAt.isNull() | t.nextAttemptAt.isSmallerOrEqualValue(now))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    for (final entry in pendingEntries) {
      try {
        await _pushSingleEntry(entry: entry, userId: userId, client: client);

        // Remote push succeeded: delete outbox entry atomically
        await (database.delete(database.syncOutbox)
              ..where((t) => t.id.equals(entry.id)))
            .go();
      } catch (e) {
        // Failed: record error and compute bounded exponential backoff
        final nextAttemptCount = entry.attemptCount + 1;
        final backoffSeconds = min(300, pow(2, min(nextAttemptCount, 7)).toInt() * 5);
        final nextAttemptAt = DateTime.now().toUtc().add(Duration(seconds: backoffSeconds));

        await (database.update(database.syncOutbox)
              ..where((t) => t.id.equals(entry.id)))
            .write(
          SyncOutboxCompanion(
            attemptCount: Value(nextAttemptCount),
            nextAttemptAt: Value(nextAttemptAt),
            lastError: Value(e.toString()),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
      }
    }
  }

  /// Pushes an individual outbox record based on entityType and operation.
  Future<void> _pushSingleEntry({
    required SyncOutboxData entry,
    required String userId,
    required RemoteSyncClient client,
  }) async {
    final entityType = entry.entityType;
    final entityId = entry.entityId;

    switch (entityType) {
      case 'person':
      case 'people':
        await _pushPerson(entityId, userId, client);
        break;
      case 'person_role':
      case 'person_roles':
        // Individual person_role outbox rows are also pushed as part of _pushPerson.
        // If enqueued directly, push the person_role record.
        await _pushPersonRole(entityId, userId, client);
        break;
      case 'site':
      case 'sites':
        await _pushSite(entityId, userId, client);
        break;
      case 'scheme':
      case 'schemes':
        await _pushScheme(entityId, userId, client);
        break;
      case 'transaction':
      case 'transactions':
        await _pushTransaction(entityId, userId, client);
        break;
      case 'expense':
      case 'expenses':
        await _pushExpense(entityId, userId, client);
        break;
      case 'vehicle':
      case 'vehicles':
        await _pushVehicle(entityId, userId, client);
        break;
      case 'vehicle_log':
      case 'vehicle_logs':
        await _pushVehicleLog(entityId, userId, client);
        break;
      case 'bill':
      case 'bills':
        await _pushBill(entityId, userId, client);
        break;
      case 'progress_update':
      case 'progress_updates':
        await _pushProgressUpdate(entityId, userId, client);
        break;
      case 'reminder':
      case 'reminders':
        await _pushReminder(entityId, userId, client);
        break;
      case 'reminder_entity_link':
      case 'reminder_entity_links':
        await _pushReminderEntityLink(entityId, userId, client);
        break;
      case 'attachment':
      case 'attachments':
        await _pushAttachment(entityId, userId, client);
        break;
    }
  }

  Future<void> _pushPerson(String id, String userId, RemoteSyncClient client) async {
    final row = await (database.select(database.people)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final data = {
      'id': row.id,
      'user_id': userId,
      'full_name': row.fullName,
      'phone_number': row.phoneNumber,
      'email': row.email,
      'address': row.address,
      'notes': row.notes,
      'is_active': row.isActive,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
    };
    await client.upsertRecord(table: 'people', record: data);

    // Also push associated roles
    final roles = await (database.select(database.personRoles)..where((t) => t.personId.equals(id))).get();
    for (final r in roles) {
      await client.upsertRecord(
        table: 'person_roles',
        record: {
          'person_id': r.personId,
          'role_code': r.roleCode,
          'user_id': userId,
        },
      );
    }
  }

  Future<void> _pushPersonRole(String roleKey, String userId, RemoteSyncClient client) async {
    // roleKey is formatted as "${personId}_${roleCode}" or personId
    final parts = roleKey.split('_');
    if (parts.length >= 2) {
      final personId = parts[0];
      final roleCode = parts.sublist(1).join('_');
      final exists = await (database.select(database.personRoles)
            ..where((t) => t.personId.equals(personId) & t.roleCode.equals(roleCode)))
          .getSingleOrNull();
      if (exists != null) {
        await client.upsertRecord(
          table: 'person_roles',
          record: {
            'person_id': personId,
            'role_code': roleCode,
            'user_id': userId,
          },
        );
      }
    }
  }

  Future<void> _pushSite(String id, String userId, RemoteSyncClient client) async {
    final row = await (database.select(database.sites)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final data = {
      'id': row.id,
      'user_id': userId,
      'name': row.name,
      'road_info': row.roadInfo,
      'latitude': row.latitude,
      'longitude': row.longitude,
      'status': row.status,
      'notes': row.notes,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
    };
    await client.upsertRecord(table: 'sites', record: data);
  }

  Future<void> _pushScheme(String id, String userId, RemoteSyncClient client) async {
    final row = await (database.select(database.schemes)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final data = {
      'id': row.id,
      'user_id': userId,
      'scheme_code': row.schemeCode,
      'name': row.name,
      'site_id': row.siteId,
      'budget': row.budget,
      'engineer_id': row.engineerId,
      'start_date': row.startDate?.toUtc().toIso8601String(),
      'end_date': row.endDate?.toUtc().toIso8601String(),
      'status': row.status,
      'progress_percentage': row.progressPercentage,
      'incomplete_reason': row.incompleteReason,
      'result': row.result,
      'description': row.description,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
    };
    await client.upsertRecord(table: 'schemes', record: data);
  }

  Future<void> _pushTransaction(String id, String userId, RemoteSyncClient client) async {
    final row = await (database.select(database.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final data = {
      'id': row.id,
      'user_id': userId,
      'transaction_code': row.transactionCode,
      'transaction_date': row.transactionDate.toUtc().toIso8601String(),
      'type': row.type,
      'person_id': row.personId,
      'amount': row.amount,
      'quantity': row.quantity,
      'purpose': row.purpose,
      'payment_method': row.paymentMethod,
      'reference_number': row.referenceNumber,
      'remarks': row.remarks,
      'scheme_id': row.schemeId,
      'site_id': row.siteId,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
    };
    await client.upsertRecord(table: 'transactions', record: data);
  }

  Future<void> _pushExpense(String id, String userId, RemoteSyncClient client) async {
    final row = await (database.select(database.expenses)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final data = {
      'id': row.id,
      'user_id': userId,
      'expense_code': row.expenseCode,
      'expense_date': row.expenseDate.toUtc().toIso8601String(),
      'category': row.category,
      'amount': row.amount,
      'purpose': row.purpose,
      'site_id': row.siteId,
      'scheme_id': row.schemeId,
      'person_id': row.personId,
      'remarks': row.remarks,
      'attachment_path': row.attachmentPath,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
    };
    await client.upsertRecord(table: 'expenses', record: data);
  }

  Future<void> _pushVehicle(String id, String userId, RemoteSyncClient client) async {
    final row = await (database.select(database.vehicles)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final data = {
      'id': row.id,
      'user_id': userId,
      'vehicle_number': row.vehicleNumber,
      'make_model': row.makeModel,
      'vehicle_type': row.vehicleType,
      'assigned_site_id': row.assignedSiteId,
      'assigned_driver_id': row.assignedDriverId,
      'status': row.status,
      'remarks': row.remarks,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
    };
    await client.upsertRecord(table: 'vehicles', record: data);
  }

  Future<void> _pushVehicleLog(String id, String userId, RemoteSyncClient client) async {
    final row = await (database.select(database.vehicleLogs)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final data = {
      'id': row.id,
      'user_id': userId,
      'vehicle_id': row.vehicleId,
      'log_date': row.logDate.toUtc().toIso8601String(),
      'log_type': row.logType,
      'amount': row.amount,
      'quantity_liters': row.quantityLiters,
      'driver_id': row.driverId,
      'site_id': row.siteId,
      'description': row.description,
      'odometer_reading': row.odometerReading,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
    };
    await client.upsertRecord(table: 'vehicle_logs', record: data);
  }

  Future<void> _pushBill(String id, String userId, RemoteSyncClient client) async {
    final row = await (database.select(database.bills)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final data = {
      'id': row.id,
      'user_id': userId,
      'scheme_id': row.schemeId,
      'bill_type': row.billType,
      'bill_number': row.billNumber,
      'bill_date': row.billDate.toUtc().toIso8601String(),
      'amount': row.amount,
      'status': row.status,
      'remarks': row.remarks,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
    };
    await client.upsertRecord(table: 'bills', record: data);
  }

  Future<void> _pushProgressUpdate(String id, String userId, RemoteSyncClient client) async {
    final row = await (database.select(database.progressUpdates)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final data = {
      'id': row.id,
      'user_id': userId,
      'scheme_id': row.schemeId,
      'site_id': row.siteId,
      'status': row.status,
      'progress_percentage': row.progressPercentage,
      'date': row.date.toUtc().toIso8601String(),
      'incomplete_reason': row.incompleteReason,
      'result': row.result,
      'remarks': row.remarks,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
    };
    await client.upsertRecord(table: 'progress_updates', record: data);
  }

  Future<void> _pushReminder(String id, String userId, RemoteSyncClient client) async {
    final row = await (database.select(database.reminders)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final data = {
      'id': row.id,
      'user_id': userId,
      'title': row.title,
      'description': row.description,
      'due_at': row.dueAt?.toUtc().toIso8601String(),
      'priority': row.priority,
      'is_done': row.isDone,
      'done_at': row.doneAt?.toUtc().toIso8601String(),
      'scheme_id': row.schemeId,
      'site_id': row.siteId,
      'remarks': row.remarks,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
    };
    await client.upsertRecord(table: 'reminders', record: data);

    // Also push associated reminder_entity_links
    final links = await (database.select(database.reminderEntityLinks)..where((t) => t.reminderId.equals(id))).get();
    for (final link in links) {
      await client.upsertRecord(
        table: 'reminder_entity_links',
        record: {
          'id': link.id,
          'user_id': userId,
          'reminder_id': link.reminderId,
          'entity_type': link.entityType,
          'entity_id': link.entityId,
          'created_at': link.createdAt.toUtc().toIso8601String(),
          'updated_at': link.updatedAt.toUtc().toIso8601String(),
          'deleted_at': link.deletedAt?.toUtc().toIso8601String(),
        },
      );
    }
  }

  Future<void> _pushReminderEntityLink(String id, String userId, RemoteSyncClient client) async {
    final row = await (database.select(database.reminderEntityLinks)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    final data = {
      'id': row.id,
      'user_id': userId,
      'reminder_id': row.reminderId,
      'entity_type': row.entityType,
      'entity_id': row.entityId,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
    };
    await client.upsertRecord(table: 'reminder_entity_links', record: data);
  }

  Future<void> _pushAttachment(String id, String userId, RemoteSyncClient client) async {
    final row = await (database.select(database.attachments)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    String? storagePath = row.storagePath;

    // If attachment has not been uploaded to cloud storage yet, and it is not soft-deleted, upload binary
    if ((storagePath == null || storagePath.trim().isEmpty) && row.deletedAt == null) {
      final sClient = storageClient;
      if (sClient != null && row.filePath != null && row.filePath!.isNotEmpty) {
        final bytes = await AttachmentFileHelper.readFileBytes(row.filePath);
        if (bytes != null && bytes.isNotEmpty) {
          final computedPath = AttachmentStorageService.buildStoragePath(
            userId: userId,
            entityType: row.entityType,
            attachmentId: row.id,
            fileName: row.fileName,
          );

          await sClient.uploadBytes(
            bucket: AttachmentStorageService.defaultBucket,
            storagePath: computedPath,
            bytes: bytes,
            mimeType: row.mimeType,
          );

          storagePath = computedPath;

          // Update local Drift record with the newly assigned storage_path
          await (database.update(database.attachments)..where((t) => t.id.equals(id))).write(
            AttachmentsCompanion(
              storagePath: Value(storagePath),
            ),
          );
        }
      }
    }

    final data = {
      'id': row.id,
      'user_id': userId,
      'entity_type': row.entityType,
      'entity_id': row.entityId,
      'file_path': row.filePath,
      'file_name': row.fileName,
      'storage_path': storagePath,
      'mime_type': row.mimeType,
      'file_size': row.fileSize,
      'image_width': row.imageWidth,
      'image_height': row.imageHeight,
      'category': row.category,
      'description': row.description,
      'captured_at': row.capturedAt.toUtc().toIso8601String(),
      'latitude': row.latitude,
      'longitude': row.longitude,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
    };
    await client.upsertRecord(table: 'attachments', record: data);
  }

  /// Step 2: Incremental / Delta Pull from Supabase PostgreSQL.
  Future<void> _pullRemoteChanges({
    required String userId,
    required RemoteSyncClient client,
  }) async {
    final lastSyncedAt = _status.lastSyncedAt;

    // Pull changes across all business tables in dependency order
    await _pullPeople(userId, client, lastSyncedAt);
    await _pullSites(userId, client, lastSyncedAt);
    await _pullSchemes(userId, client, lastSyncedAt);
    await _pullTransactions(userId, client, lastSyncedAt);
    await _pullExpenses(userId, client, lastSyncedAt);
    await _pullVehicles(userId, client, lastSyncedAt);
    await _pullVehicleLogs(userId, client, lastSyncedAt);
    await _pullBills(userId, client, lastSyncedAt);
    await _pullProgressUpdates(userId, client, lastSyncedAt);
    await _pullReminders(userId, client, lastSyncedAt);
    await _pullReminderEntityLinks(userId, client, lastSyncedAt);
    await _pullAttachments(userId, client, lastSyncedAt);
  }

  /// Conflict resolution helper: returns true if the remote record should overwrite local.
  /// Rule: Remote wins if remote.updatedAt > local.updatedAt, or if timestamps match and remote is tie-breaker.
  bool shouldRemoteOverwrite({
    required DateTime? localUpdatedAt,
    required DateTime remoteUpdatedAt,
  }) {
    if (localUpdatedAt == null) return true;
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) return true;
    if (remoteUpdatedAt.isAtSameMomentAs(localUpdatedAt)) return true; // Deterministic tie-break: cloud state
    return false;
  }

  Future<void> _pullPeople(String userId, RemoteSyncClient client, DateTime? since) async {
    final remoteRecords = await client.fetchUpdatedSince(table: 'people', userId: userId, since: since);
    for (final r in remoteRecords) {
      final id = r['id'] as String;
      final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final local = await (database.select(database.people)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (local == null || shouldRemoteOverwrite(localUpdatedAt: local.updatedAt, remoteUpdatedAt: remoteUpdatedAt)) {
        await database.into(database.people).insertOnConflictUpdate(
              PeopleCompanion(
                id: Value(id),
                fullName: Value(r['full_name'] as String),
                phoneNumber: Value(r['phone_number'] as String?),
                email: Value(r['email'] as String?),
                address: Value(r['address'] as String?),
                notes: Value(r['notes'] as String?),
                isActive: Value(r['is_active'] as bool? ?? true),
                createdAt: Value(DateTime.parse(r['created_at'] as String)),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(r['deleted_at'] != null ? DateTime.parse(r['deleted_at'] as String) : null),
                syncStatus: const Value('synced'),
                remoteUpdatedAt: Value(remoteUpdatedAt),
                lastSyncedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
    }
  }

  Future<void> _pullSites(String userId, RemoteSyncClient client, DateTime? since) async {
    final remoteRecords = await client.fetchUpdatedSince(table: 'sites', userId: userId, since: since);
    for (final r in remoteRecords) {
      final id = r['id'] as String;
      final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final local = await (database.select(database.sites)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (local == null || shouldRemoteOverwrite(localUpdatedAt: local.updatedAt, remoteUpdatedAt: remoteUpdatedAt)) {
        await database.into(database.sites).insertOnConflictUpdate(
              SitesCompanion(
                id: Value(id),
                name: Value(r['name'] as String),
                roadInfo: Value(r['road_info'] as String?),
                latitude: Value((r['latitude'] as num?)?.toDouble()),
                longitude: Value((r['longitude'] as num?)?.toDouble()),
                status: Value(r['status'] as String? ?? 'active'),
                notes: Value(r['notes'] as String?),
                createdAt: Value(DateTime.parse(r['created_at'] as String)),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(r['deleted_at'] != null ? DateTime.parse(r['deleted_at'] as String) : null),
                syncStatus: const Value('synced'),
                remoteUpdatedAt: Value(remoteUpdatedAt),
                lastSyncedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
    }
  }

  Future<void> _pullSchemes(String userId, RemoteSyncClient client, DateTime? since) async {
    final remoteRecords = await client.fetchUpdatedSince(table: 'schemes', userId: userId, since: since);
    for (final r in remoteRecords) {
      final id = r['id'] as String;
      final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final local = await (database.select(database.schemes)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (local == null || shouldRemoteOverwrite(localUpdatedAt: local.updatedAt, remoteUpdatedAt: remoteUpdatedAt)) {
        await database.into(database.schemes).insertOnConflictUpdate(
              SchemesCompanion(
                id: Value(id),
                schemeCode: Value(r['scheme_code'] as String),
                name: Value(r['name'] as String),
                siteId: Value(r['site_id'] as String?),
                budget: Value((r['budget'] as num?)?.toInt() ?? 0),
                engineerId: Value(r['engineer_id'] as String?),
                startDate: Value(r['start_date'] != null ? DateTime.parse(r['start_date'] as String) : null),
                endDate: Value(r['end_date'] != null ? DateTime.parse(r['end_date'] as String) : null),
                status: Value(r['status'] as String? ?? 'initial'),
                progressPercentage: Value((r['progress_percentage'] as num?)?.toDouble() ?? 0.0),
                incompleteReason: Value(r['incomplete_reason'] as String?),
                result: Value(r['result'] as String?),
                description: Value(r['description'] as String?),
                createdAt: Value(DateTime.parse(r['created_at'] as String)),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(r['deleted_at'] != null ? DateTime.parse(r['deleted_at'] as String) : null),
                syncStatus: const Value('synced'),
                remoteUpdatedAt: Value(remoteUpdatedAt),
                lastSyncedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
    }
  }

  Future<void> _pullTransactions(String userId, RemoteSyncClient client, DateTime? since) async {
    final remoteRecords = await client.fetchUpdatedSince(table: 'transactions', userId: userId, since: since);
    for (final r in remoteRecords) {
      final id = r['id'] as String;
      final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final local = await (database.select(database.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (local == null || shouldRemoteOverwrite(localUpdatedAt: local.updatedAt, remoteUpdatedAt: remoteUpdatedAt)) {
        await database.into(database.transactions).insertOnConflictUpdate(
              TransactionsCompanion(
                id: Value(id),
                transactionCode: Value(r['transaction_code'] as String),
                transactionDate: Value(DateTime.parse(r['transaction_date'] as String)),
                type: Value(r['type'] as String),
                personId: Value(r['person_id'] as String?),
                amount: Value((r['amount'] as num?)?.toInt() ?? 0),
                quantity: Value((r['quantity'] as num?)?.toDouble()),
                purpose: Value(r['purpose'] as String),
                paymentMethod: Value(r['payment_method'] as String? ?? 'cash'),
                referenceNumber: Value(r['reference_number'] as String?),
                remarks: Value(r['remarks'] as String?),
                schemeId: Value(r['scheme_id'] as String?),
                siteId: Value(r['site_id'] as String?),
                createdAt: Value(DateTime.parse(r['created_at'] as String)),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(r['deleted_at'] != null ? DateTime.parse(r['deleted_at'] as String) : null),
                syncStatus: const Value('synced'),
                remoteUpdatedAt: Value(remoteUpdatedAt),
                lastSyncedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
    }
  }

  Future<void> _pullExpenses(String userId, RemoteSyncClient client, DateTime? since) async {
    final remoteRecords = await client.fetchUpdatedSince(table: 'expenses', userId: userId, since: since);
    for (final r in remoteRecords) {
      final id = r['id'] as String;
      final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final local = await (database.select(database.expenses)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (local == null || shouldRemoteOverwrite(localUpdatedAt: local.updatedAt, remoteUpdatedAt: remoteUpdatedAt)) {
        await database.into(database.expenses).insertOnConflictUpdate(
              ExpensesCompanion(
                id: Value(id),
                expenseCode: Value(r['expense_code'] as String),
                expenseDate: Value(DateTime.parse(r['expense_date'] as String)),
                category: Value(r['category'] as String),
                amount: Value((r['amount'] as num?)?.toInt() ?? 0),
                purpose: Value(r['purpose'] as String),
                siteId: Value(r['site_id'] as String?),
                schemeId: Value(r['scheme_id'] as String?),
                personId: Value(r['person_id'] as String?),
                remarks: Value(r['remarks'] as String?),
                attachmentPath: Value(r['attachment_path'] as String?),
                createdAt: Value(DateTime.parse(r['created_at'] as String)),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(r['deleted_at'] != null ? DateTime.parse(r['deleted_at'] as String) : null),
                syncStatus: const Value('synced'),
                remoteUpdatedAt: Value(remoteUpdatedAt),
                lastSyncedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
    }
  }

  Future<void> _pullVehicles(String userId, RemoteSyncClient client, DateTime? since) async {
    final remoteRecords = await client.fetchUpdatedSince(table: 'vehicles', userId: userId, since: since);
    for (final r in remoteRecords) {
      final id = r['id'] as String;
      final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final local = await (database.select(database.vehicles)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (local == null || shouldRemoteOverwrite(localUpdatedAt: local.updatedAt, remoteUpdatedAt: remoteUpdatedAt)) {
        await database.into(database.vehicles).insertOnConflictUpdate(
              VehiclesCompanion(
                id: Value(id),
                vehicleNumber: Value(r['vehicle_number'] as String),
                makeModel: Value(r['make_model'] as String),
                vehicleType: Value(r['vehicle_type'] as String? ?? 'truck'),
                assignedSiteId: Value(r['assigned_site_id'] as String?),
                assignedDriverId: Value(r['assigned_driver_id'] as String?),
                status: Value(r['status'] as String? ?? 'active'),
                remarks: Value(r['remarks'] as String?),
                createdAt: Value(DateTime.parse(r['created_at'] as String)),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(r['deleted_at'] != null ? DateTime.parse(r['deleted_at'] as String) : null),
                syncStatus: const Value('synced'),
                remoteUpdatedAt: Value(remoteUpdatedAt),
                lastSyncedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
    }
  }

  Future<void> _pullVehicleLogs(String userId, RemoteSyncClient client, DateTime? since) async {
    final remoteRecords = await client.fetchUpdatedSince(table: 'vehicle_logs', userId: userId, since: since);
    for (final r in remoteRecords) {
      final id = r['id'] as String;
      final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final local = await (database.select(database.vehicleLogs)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (local == null || shouldRemoteOverwrite(localUpdatedAt: local.updatedAt, remoteUpdatedAt: remoteUpdatedAt)) {
        await database.into(database.vehicleLogs).insertOnConflictUpdate(
              VehicleLogsCompanion(
                id: Value(id),
                vehicleId: Value(r['vehicle_id'] as String),
                logDate: Value(DateTime.parse(r['log_date'] as String)),
                logType: Value(r['log_type'] as String),
                amount: Value((r['amount'] as num?)?.toInt() ?? 0),
                quantityLiters: Value((r['quantity_liters'] as num?)?.toDouble()),
                driverId: Value(r['driver_id'] as String?),
                siteId: Value(r['site_id'] as String?),
                description: Value(r['description'] as String),
                odometerReading: Value((r['odometer_reading'] as num?)?.toDouble()),
                createdAt: Value(DateTime.parse(r['created_at'] as String)),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(r['deleted_at'] != null ? DateTime.parse(r['deleted_at'] as String) : null),
                syncStatus: const Value('synced'),
                remoteUpdatedAt: Value(remoteUpdatedAt),
                lastSyncedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
    }
  }

  Future<void> _pullBills(String userId, RemoteSyncClient client, DateTime? since) async {
    final remoteRecords = await client.fetchUpdatedSince(table: 'bills', userId: userId, since: since);
    for (final r in remoteRecords) {
      final id = r['id'] as String;
      final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final local = await (database.select(database.bills)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (local == null || shouldRemoteOverwrite(localUpdatedAt: local.updatedAt, remoteUpdatedAt: remoteUpdatedAt)) {
        await database.into(database.bills).insertOnConflictUpdate(
              BillsCompanion(
                id: Value(id),
                schemeId: Value(r['scheme_id'] as String),
                billType: Value(r['bill_type'] as String),
                billNumber: Value(r['bill_number'] as String?),
                billDate: Value(DateTime.parse(r['bill_date'] as String)),
                amount: Value((r['amount'] as num?)?.toInt() ?? 0),
                status: Value(r['status'] as String? ?? 'draft'),
                remarks: Value(r['remarks'] as String?),
                createdAt: Value(DateTime.parse(r['created_at'] as String)),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(r['deleted_at'] != null ? DateTime.parse(r['deleted_at'] as String) : null),
                syncStatus: const Value('synced'),
                remoteUpdatedAt: Value(remoteUpdatedAt),
                lastSyncedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
    }
  }

  Future<void> _pullProgressUpdates(String userId, RemoteSyncClient client, DateTime? since) async {
    final remoteRecords = await client.fetchUpdatedSince(table: 'progress_updates', userId: userId, since: since);
    for (final r in remoteRecords) {
      final id = r['id'] as String;
      final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final local = await (database.select(database.progressUpdates)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (local == null || shouldRemoteOverwrite(localUpdatedAt: local.updatedAt, remoteUpdatedAt: remoteUpdatedAt)) {
        await database.into(database.progressUpdates).insertOnConflictUpdate(
              ProgressUpdatesCompanion(
                id: Value(id),
                schemeId: Value(r['scheme_id'] as String),
                siteId: Value(r['site_id'] as String?),
                status: Value(r['status'] as String),
                progressPercentage: Value((r['progress_percentage'] as num?)?.toDouble() ?? 0.0),
                date: Value(DateTime.parse(r['date'] as String)),
                incompleteReason: Value(r['incomplete_reason'] as String?),
                result: Value(r['result'] as String?),
                remarks: Value(r['remarks'] as String?),
                createdAt: Value(DateTime.parse(r['created_at'] as String)),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(r['deleted_at'] != null ? DateTime.parse(r['deleted_at'] as String) : null),
                syncStatus: const Value('synced'),
                remoteUpdatedAt: Value(remoteUpdatedAt),
                lastSyncedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
    }
  }

  Future<void> _pullReminders(String userId, RemoteSyncClient client, DateTime? since) async {
    final remoteRecords = await client.fetchUpdatedSince(table: 'reminders', userId: userId, since: since);
    for (final r in remoteRecords) {
      final id = r['id'] as String;
      final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final local = await (database.select(database.reminders)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (local == null || shouldRemoteOverwrite(localUpdatedAt: local.updatedAt, remoteUpdatedAt: remoteUpdatedAt)) {
        await database.into(database.reminders).insertOnConflictUpdate(
              RemindersCompanion(
                id: Value(id),
                title: Value(r['title'] as String),
                description: Value(r['description'] as String?),
                dueAt: Value(r['due_at'] != null ? DateTime.parse(r['due_at'] as String) : null),
                priority: Value(r['priority'] as String? ?? 'medium'),
                isDone: Value(r['is_done'] as bool? ?? false),
                doneAt: Value(r['done_at'] != null ? DateTime.parse(r['done_at'] as String) : null),
                schemeId: Value(r['scheme_id'] as String?),
                siteId: Value(r['site_id'] as String?),
                remarks: Value(r['remarks'] as String?),
                createdAt: Value(DateTime.parse(r['created_at'] as String)),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(r['deleted_at'] != null ? DateTime.parse(r['deleted_at'] as String) : null),
                syncStatus: const Value('synced'),
                remoteUpdatedAt: Value(remoteUpdatedAt),
                lastSyncedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
    }
  }

  Future<void> _pullReminderEntityLinks(String userId, RemoteSyncClient client, DateTime? since) async {
    final remoteRecords = await client.fetchUpdatedSince(table: 'reminder_entity_links', userId: userId, since: since);
    for (final r in remoteRecords) {
      final id = r['id'] as String;
      final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final local = await (database.select(database.reminderEntityLinks)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (local == null || shouldRemoteOverwrite(localUpdatedAt: local.updatedAt, remoteUpdatedAt: remoteUpdatedAt)) {
        await database.into(database.reminderEntityLinks).insertOnConflictUpdate(
              ReminderEntityLinksCompanion(
                id: Value(id),
                reminderId: Value(r['reminder_id'] as String),
                entityType: Value(r['entity_type'] as String),
                entityId: Value(r['entity_id'] as String),
                createdAt: Value(DateTime.parse(r['created_at'] as String)),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(r['deleted_at'] != null ? DateTime.parse(r['deleted_at'] as String) : null),
                syncStatus: const Value('synced'),
                remoteUpdatedAt: Value(remoteUpdatedAt),
                lastSyncedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
    }
  }

  Future<void> _pullAttachments(String userId, RemoteSyncClient client, DateTime? since) async {
    final remoteRecords = await client.fetchUpdatedSince(table: 'attachments', userId: userId, since: since);
    for (final r in remoteRecords) {
      final id = r['id'] as String;
      final remoteUpdatedAt = DateTime.parse(r['updated_at'] as String);
      final local = await (database.select(database.attachments)..where((t) => t.id.equals(id))).getSingleOrNull();

      if (local == null || shouldRemoteOverwrite(localUpdatedAt: local.updatedAt, remoteUpdatedAt: remoteUpdatedAt)) {
        // Keep existing local filePath if already present on this device
        final effectiveFilePath = local?.filePath ?? (r['file_path'] as String?);

        await database.into(database.attachments).insertOnConflictUpdate(
              AttachmentsCompanion(
                id: Value(id),
                entityType: Value(r['entity_type'] as String),
                entityId: Value(r['entity_id'] as String),
                filePath: Value(effectiveFilePath),
                fileName: Value(r['file_name'] as String),
                storagePath: Value(r['storage_path'] as String?),
                mimeType: Value(r['mime_type'] as String?),
                fileSize: Value((r['file_size'] as num?)?.toInt()),
                imageWidth: Value((r['image_width'] as num?)?.toInt()),
                imageHeight: Value((r['image_height'] as num?)?.toInt()),
                category: Value(r['category'] as String? ?? 'other'),
                description: Value(r['description'] as String?),
                capturedAt: Value(DateTime.parse(r['captured_at'] as String)),
                latitude: Value((r['latitude'] as num?)?.toDouble()),
                longitude: Value((r['longitude'] as num?)?.toDouble()),
                createdAt: Value(DateTime.parse(r['created_at'] as String)),
                updatedAt: Value(remoteUpdatedAt),
                deletedAt: Value(r['deleted_at'] != null ? DateTime.parse(r['deleted_at'] as String) : null),
                syncStatus: const Value('synced'),
                remoteUpdatedAt: Value(remoteUpdatedAt),
                lastSyncedAt: Value(DateTime.now().toUtc()),
              ),
            );
      }
    }
  }

  void dispose() {
    _statusController.close();
  }
}
