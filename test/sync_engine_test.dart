import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';
import 'package:offline_finance_management_app/src/core/sync/sync_engine.dart';
import 'package:offline_finance_management_app/src/features/documents/data/attachment_storage_service.dart';
import 'package:uuid/uuid.dart';

/// In-memory mock for [RemoteSyncClient] to simulate Supabase operations and responses.
class MockRemoteSyncClient implements RemoteSyncClient {
  final Map<String, List<Map<String, dynamic>>> tables = {};
  bool shouldThrow = false;
  int upsertCallCount = 0;

  @override
  Future<void> upsertRecord({
    required String table,
    required Map<String, dynamic> record,
  }) async {
    if (shouldThrow) throw Exception('Network error / connection refused');
    upsertCallCount++;
    tables.putIfAbsent(table, () => []);
    final list = tables[table]!;
    final index = list.indexWhere((r) => r['id'] == record['id']);
    if (index >= 0) {
      list[index] = Map<String, dynamic>.from(record);
    } else {
      list.add(Map<String, dynamic>.from(record));
    }
  }

  @override
  Future<void> updateRecord({
    required String table,
    required String id,
    required Map<String, dynamic> updates,
  }) async {
    if (shouldThrow) throw Exception('Network error');
    final list = tables[table] ?? [];
    final index = list.indexWhere((r) => r['id'] == id);
    if (index >= 0) {
      list[index].addAll(updates);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchUpdatedSince({
    required String table,
    required String userId,
    DateTime? since,
  }) async {
    if (shouldThrow) throw Exception('Network error');
    final list = tables[table] ?? [];
    return list.where((r) {
      if (r['user_id'] != userId) return false;
      if (since == null) return true;
      final updatedAt = DateTime.parse(r['updated_at'] as String);
      return updatedAt.isAfter(since);
    }).toList();
  }
}

/// In-memory mock for [AttachmentStorageClient] to simulate Supabase Storage operations.
class MockAttachmentStorageClient implements AttachmentStorageClient {
  final Map<String, Uint8List> storage = {};
  bool shouldThrow = false;
  int uploadCallCount = 0;
  int downloadCallCount = 0;
  int deleteCallCount = 0;

  @override
  Future<String> uploadBytes({
    required String bucket,
    required String storagePath,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    if (shouldThrow) throw Exception('Storage network timeout / error');
    uploadCallCount++;
    final key = '$bucket/$storagePath';
    storage[key] = bytes;
    return storagePath;
  }

  @override
  Future<Uint8List> downloadBytes({
    required String bucket,
    required String storagePath,
  }) async {
    if (shouldThrow) throw Exception('Storage download failed');
    downloadCallCount++;
    final key = '$bucket/$storagePath';
    final bytes = storage[key];
    if (bytes == null) {
      throw Exception('File not found in mock storage: $key');
    }
    return bytes;
  }

  @override
  Future<void> deleteFile({
    required String bucket,
    required String storagePath,
  }) async {
    if (shouldThrow) throw Exception('Storage delete failed');
    deleteCallCount++;
    final key = '$bucket/$storagePath';
    storage.remove(key);
  }

  @override
  Future<String?> createSignedUrl({
    required String bucket,
    required String storagePath,
    int expiresInSeconds = 3600,
  }) async {
    if (shouldThrow) throw Exception('Failed to sign URL');
    return 'https://mock.storage.test/$bucket/$storagePath?signed=true';
  }
}

void main() {
  late AppDatabase database;
  late MockRemoteSyncClient remoteClient;
  late MockAttachmentStorageClient storageClient;
  late SyncEngine syncEngine;
  const testUserId = 'user-1234-5678-90ab';
  const uuid = Uuid();

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    remoteClient = MockRemoteSyncClient();
    storageClient = MockAttachmentStorageClient();
    syncEngine = SyncEngine(
      database: database,
      remoteClient: remoteClient,
      storageClient: storageClient,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await database.close();
  });

  group('SyncEngine Unit Tests', () {
    test('skips synchronization if userId is null or unauthenticated', () async {
      final success = await syncEngine.sync(userId: null);
      expect(success, isFalse);
      expect(syncEngine.status.state, equals(SyncEngineState.idle));
    });

    test('skips synchronization if remoteClient is not configured (offline mode)', () async {
      final engineWithoutClient = SyncEngine(database: database, remoteClient: null);
      final success = await engineWithoutClient.sync(userId: testUserId);
      expect(success, isFalse);
      expect(engineWithoutClient.status.state, equals(SyncEngineState.offline));
      engineWithoutClient.dispose();
    });

    test('pushes local insert from SyncOutbox to remote and deletes outbox row', () async {
      final personId = uuid.v4();
      final now = DateTime.now().toUtc();

      // 1. Insert local person record
      await database.into(database.people).insert(
            PeopleCompanion.insert(
              id: personId,
              fullName: 'John Doe',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 2. Insert outbox entry
      await database.into(database.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              id: uuid.v4(),
              entityType: 'people',
              entityId: personId,
              operation: 'insert',
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      expect(await database.syncOutbox.count().getSingle(), equals(1));

      // 3. Run sync
      final success = await syncEngine.sync(userId: testUserId);
      expect(success, isTrue);

      // 4. Assert outbox was processed and removed
      expect(await database.syncOutbox.count().getSingle(), equals(0));

      // 5. Assert remote client received the record with correct user_id
      final remotePeople = remoteClient.tables['people'];
      expect(remotePeople, isNotNull);
      expect(remotePeople!.length, equals(1));
      expect(remotePeople.first['id'], equals(personId));
      expect(remotePeople.first['user_id'], equals(testUserId));
      expect(remotePeople.first['full_name'], equals('John Doe'));
    });

    test('soft delete propagates to remote client with deleted_at timestamp', () async {
      final siteId = uuid.v4();
      final createdTime = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final deletedTime = DateTime.now().toUtc();

      // Insert soft-deleted site
      await database.into(database.sites).insert(
            SitesCompanion.insert(
              id: siteId,
              name: 'Site Alpha',
              createdAt: createdTime,
              updatedAt: deletedTime,
              deletedAt: Value(deletedTime),
            ),
          );

      // Enqueue delete outbox
      await database.into(database.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              id: uuid.v4(),
              entityType: 'sites',
              entityId: siteId,
              operation: 'delete',
              createdAt: Value(deletedTime),
              updatedAt: Value(deletedTime),
            ),
          );

      final success = await syncEngine.sync(userId: testUserId);
      expect(success, isTrue);
      expect(await database.syncOutbox.count().getSingle(), equals(0));

      final remoteSites = remoteClient.tables['sites'];
      expect(remoteSites, isNotNull);
      expect(remoteSites!.first['deleted_at'], isNotNull);
    });

    test('network failure leaves outbox row intact and updates attemptCount + backoff', () async {
      final schemeId = uuid.v4();
      final now = DateTime.now().toUtc();

      await database.into(database.schemes).insert(
            SchemesCompanion.insert(
              id: schemeId,
              schemeCode: 'SC-01',
              name: 'Scheme 1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await database.into(database.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              id: uuid.v4(),
              entityType: 'schemes',
              entityId: schemeId,
              operation: 'insert',
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // Simulate remote failure
      remoteClient.shouldThrow = true;

      final success = await syncEngine.sync(userId: testUserId);
      expect(success, isFalse);
      expect(syncEngine.status.state, equals(SyncEngineState.failed));

      // Outbox row must still exist
      final outbox = await database.select(database.syncOutbox).get();
      expect(outbox.length, equals(1));
      expect(outbox.first.attemptCount, equals(1));
      expect(outbox.first.nextAttemptAt, isNotNull);
      expect(outbox.first.lastError, contains('Network error'));
    });

    test('pulls remote newer changes and applies them locally without outbox loops', () async {
      final remoteExpenseId = uuid.v4();
      final remoteCreatedAt = DateTime.now().toUtc().subtract(const Duration(minutes: 10));
      final remoteUpdatedAt = DateTime.now().toUtc().subtract(const Duration(minutes: 5));

      // Populate remote client
      remoteClient.tables['expenses'] = [
        {
          'id': remoteExpenseId,
          'user_id': testUserId,
          'expense_code': 'EXP-999',
          'expense_date': remoteCreatedAt.toIso8601String(),
          'category': 'Material',
          'amount': 50000,
          'purpose': 'Cement bags',
          'site_id': null,
          'scheme_id': null,
          'person_id': null,
          'remarks': 'Remote invoice',
          'attachment_path': null,
          'created_at': remoteCreatedAt.toIso8601String(),
          'updated_at': remoteUpdatedAt.toIso8601String(),
          'deleted_at': null,
        }
      ];

      final success = await syncEngine.sync(userId: testUserId);
      expect(success, isTrue);

      // Assert expense was saved in SQLite locally
      final localExpense = await (database.select(database.expenses)
            ..where((t) => t.id.equals(remoteExpenseId)))
          .getSingleOrNull();

      expect(localExpense, isNotNull);
      expect(localExpense!.expenseCode, equals('EXP-999'));
      expect(localExpense.syncStatus, equals('synced'));

      // Assert NO outbox entries were created by applying the pull
      expect(await database.syncOutbox.count().getSingle(), equals(0));
    });

    test('conflict resolution (LWW): local newer mutation wins over older remote', () async {
      final transactionId = uuid.v4();
      final remoteTime = DateTime.now().toUtc().subtract(const Duration(minutes: 10));
      final localNewerTime = DateTime.now().toUtc().subtract(const Duration(minutes: 1));

      // Local has a newer amount update
      await database.into(database.transactions).insert(
            TransactionsCompanion.insert(
              id: transactionId,
              transactionCode: 'TX-01',
              transactionDate: localNewerTime,
              type: 'paid',
              amount: const Value(99000), // Newer amount
              purpose: 'Local modification',
              createdAt: remoteTime,
              updatedAt: localNewerTime,
            ),
          );

      // Remote has older amount
      remoteClient.tables['transactions'] = [
        {
          'id': transactionId,
          'user_id': testUserId,
          'transaction_code': 'TX-01',
          'transaction_date': remoteTime.toIso8601String(),
          'type': 'paid',
          'person_id': null,
          'amount': 50000, // Older amount
          'purpose': 'Old remote record',
          'payment_method': 'cash',
          'reference_number': null,
          'remarks': null,
          'scheme_id': null,
          'site_id': null,
          'created_at': remoteTime.toIso8601String(),
          'updated_at': remoteTime.toIso8601String(),
          'deleted_at': null,
        }
      ];

      // Run pull / sync
      await syncEngine.sync(userId: testUserId);

      // Assert local record was preserved and NOT overwritten by older remote
      final currentLocal = await (database.select(database.transactions)
            ..where((t) => t.id.equals(transactionId)))
          .getSingle();

      expect(currentLocal.amount, equals(99000));
      expect(currentLocal.purpose, equals('Local modification'));
    });

    test('remotely deleted record applies soft delete locally', () async {
      final billId = uuid.v4();
      final createdTime = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final remoteDeletedTime = DateTime.now().toUtc().subtract(const Duration(minutes: 2));

      // Initially active local bill
      await database.into(database.bills).insert(
            BillsCompanion.insert(
              id: billId,
              schemeId: 'dummy-scheme',
              billType: 'first',
              billDate: createdTime,
              amount: const Value(10000),
              createdAt: createdTime,
              updatedAt: createdTime,
            ),
          );

      // Remote has been soft deleted
      remoteClient.tables['bills'] = [
        {
          'id': billId,
          'user_id': testUserId,
          'scheme_id': 'dummy-scheme',
          'bill_type': 'first',
          'bill_number': null,
          'bill_date': createdTime.toIso8601String(),
          'amount': 10000,
          'status': 'draft',
          'remarks': null,
          'created_at': createdTime.toIso8601String(),
          'updated_at': remoteDeletedTime.toIso8601String(),
          'deleted_at': remoteDeletedTime.toIso8601String(),
        }
      ];

      await syncEngine.sync(userId: testUserId);

      final localBill = await (database.select(database.bills)
            ..where((t) => t.id.equals(billId)))
          .getSingle();

      expect(localBill.deletedAt, isNotNull);
      expect(localBill.deletedAt!.difference(remoteDeletedTime).inSeconds.abs(), lessThanOrEqualTo(1));
    });

    group('Phase 5: Attachment Binary & Storage Synchronization', () {
      test('buildStoragePath creates deterministic user-scoped path', () {
        final path = AttachmentStorageService.buildStoragePath(
          userId: 'usr-999',
          entityType: 'scheme',
          attachmentId: 'att-123',
          fileName: 'site photo #1.jpg',
        );

        expect(path, equals('usr-999/scheme/att-123/site_photo__1.jpg'));
      });

      test('AttachmentStorageService prevents upload when client is unconfigured/offline', () async {
        final service = AttachmentStorageService(storageClient: null);
        expect(
          () => service.uploadAttachment(
            userId: testUserId,
            entityType: 'scheme',
            attachmentId: 'att-1',
            fileName: 'doc.pdf',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('AttachmentStorageService prevents download when client is unconfigured/offline', () async {
        final service = AttachmentStorageService(storageClient: null);
        expect(
          () => service.downloadAttachment(storagePath: 'some/path/file.pdf'),
          throwsA(isA<StateError>()),
        );
      });

      test('successful upload via AttachmentStorageService stores bytes deterministically', () async {
        final service = AttachmentStorageService(storageClient: storageClient);
        final bytes = Uint8List.fromList([10, 20, 30, 40]);

        final path = await service.uploadAttachment(
          userId: testUserId,
          entityType: 'expense',
          attachmentId: 'att-55',
          fileName: 'invoice.pdf',
          bytes: bytes,
          mimeType: 'application/pdf',
        );

        expect(path, equals('$testUserId/expense/att-55/invoice.pdf'));
        expect(storageClient.uploadCallCount, equals(1));

        // Download and verify exact bytes
        final downloaded = await service.downloadAttachment(storagePath: path);
        expect(downloaded, equals(bytes));
        expect(storageClient.downloadCallCount, equals(1));
      });

      test('duplicate upload does not fail and overwrites idempotently', () async {
        final service = AttachmentStorageService(storageClient: storageClient);
        final bytes = Uint8List.fromList([1, 2, 3]);

        final path1 = await service.uploadAttachment(
          userId: testUserId,
          entityType: 'scheme',
          attachmentId: 'att-dup',
          fileName: 'photo.jpg',
          bytes: bytes,
        );

        final path2 = await service.uploadAttachment(
          userId: testUserId,
          entityType: 'scheme',
          attachmentId: 'att-dup',
          fileName: 'photo.jpg',
          bytes: bytes,
        );

        expect(path1, equals(path2));
        expect(storageClient.uploadCallCount, equals(2));
      });

      test('pushes attachment metadata to Supabase when already has storagePath', () async {
        final attId = uuid.v4();
        final now = DateTime.now().toUtc();
        final existingCloudPath = '$testUserId/bill/$attId/receipt.png';

        // 1. Insert local attachment record already marked with storagePath
        await database.into(database.attachments).insert(
              AttachmentsCompanion.insert(
                id: attId,
                entityType: 'bill',
                entityId: 'bill-123',
                fileName: 'receipt.png',
                storagePath: Value(existingCloudPath),
                fileSize: const Value(1024),
                category: const Value('receipt'),
                capturedAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );

        // 2. Insert outbox entry
        await database.into(database.syncOutbox).insert(
              SyncOutboxCompanion.insert(
                id: uuid.v4(),
                entityType: 'attachment',
                entityId: attId,
                operation: 'insert',
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        // 3. Run sync
        final success = await syncEngine.sync(userId: testUserId);
        expect(success, isTrue);

        // 4. Assert remote client received the attachment record
        final remoteAttachments = remoteClient.tables['attachments'];
        expect(remoteAttachments, isNotNull);
        expect(remoteAttachments!.length, equals(1));
        expect(remoteAttachments.first['id'], equals(attId));
        expect(remoteAttachments.first['storage_path'], equals(existingCloudPath));
        expect(remoteAttachments.first['user_id'], equals(testUserId));
      });

      test('pulls remote attachment with storage_path and preserves local filePath if set', () async {
        final attId = uuid.v4();
        final remoteCreatedAt = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
        final remoteUpdatedAt = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
        final cloudStoragePath = '$testUserId/scheme/$attId/site_photo.jpg';

        // Populate remote database
        remoteClient.tables['attachments'] = [
          {
            'id': attId,
            'user_id': testUserId,
            'entity_type': 'scheme',
            'entity_id': 'scheme-777',
            'file_path': null, // Remote doesn't carry local device path
            'file_name': 'site_photo.jpg',
            'storage_path': cloudStoragePath,
            'mime_type': 'image/jpeg',
            'file_size': 2048,
            'image_width': 800,
            'image_height': 600,
            'category': 'photo',
            'description': 'Foundation photo',
            'captured_at': remoteCreatedAt.toIso8601String(),
            'latitude': 33.6844,
            'longitude': 73.0479,
            'created_at': remoteCreatedAt.toIso8601String(),
            'updated_at': remoteUpdatedAt.toIso8601String(),
            'deleted_at': null,
          }
        ];

        final success = await syncEngine.sync(userId: testUserId);
        expect(success, isTrue);

        final localAtt = await (database.select(database.attachments)
              ..where((t) => t.id.equals(attId)))
            .getSingleOrNull();

        expect(localAtt, isNotNull);
        expect(localAtt!.storagePath, equals(cloudStoragePath));
        expect(localAtt.fileName, equals('site_photo.jpg'));
        expect(localAtt.latitude, equals(33.6844));
        expect(localAtt.syncStatus, equals('synced'));
      });

      test('soft-deleted attachment syncs deleted_at and skips uploading binary', () async {
        final attId = uuid.v4();
        final now = DateTime.now().toUtc();

        await database.into(database.attachments).insert(
              AttachmentsCompanion.insert(
                id: attId,
                entityType: 'expense',
                entityId: 'exp-1',
                fileName: 'deleted_receipt.jpg',
                filePath: const Value('/some/deleted/local/path.jpg'),
                storagePath: const Value(null),
                category: const Value('receipt'),
                capturedAt: now,
                createdAt: now,
                updatedAt: now,
                deletedAt: Value(now),
              ),
            );

        await database.into(database.syncOutbox).insert(
              SyncOutboxCompanion.insert(
                id: uuid.v4(),
                entityType: 'attachment',
                entityId: attId,
                operation: 'delete',
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        final success = await syncEngine.sync(userId: testUserId);
        expect(success, isTrue);

        // Binary storage upload was skipped because deletedAt != null
        expect(storageClient.uploadCallCount, equals(0));

        // Remote metadata table received the soft-deleted attachment
        final remoteAtts = remoteClient.tables['attachments'];
        expect(remoteAtts, isNotNull);
        expect(remoteAtts!.first['deleted_at'], isNotNull);
      });

      test('storage error handling and deleteFile', () async {
        final service = AttachmentStorageService(storageClient: storageClient);

        // Deleting when file exists
        storageClient.storage['attachments/test/path.jpg'] = Uint8List.fromList([1, 2]);
        await service.deleteAttachment(storagePath: 'test/path.jpg');
        expect(storageClient.deleteCallCount, equals(1));
        expect(storageClient.storage.containsKey('attachments/test/path.jpg'), isFalse);

        // Storage failure during download throws
        storageClient.shouldThrow = true;
        expect(
          () => service.downloadAttachment(storagePath: 'any/file.pdf'),
          throwsException,
        );
      });
    });

    group('Phase 6: Integration & Sync Hardening', () {
      test('pushes reminder along with its reminder_entity_links to remote', () async {
        final reminderId = uuid.v4();
        final linkId = uuid.v4();
        final now = DateTime.now().toUtc();

        // 1. Insert local reminder
        await database.into(database.reminders).insert(
              RemindersCompanion.insert(
                id: reminderId,
                title: 'Review bill documents',
                priority: const Value('high'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        // 2. Insert reminder entity link
        await database.into(database.reminderEntityLinks).insert(
              ReminderEntityLinksCompanion.insert(
                id: linkId,
                reminderId: reminderId,
                entityType: 'bill',
                entityId: 'bill-999',
                createdAt: now,
                updatedAt: now,
              ),
            );

        // 3. Enqueue outbox for reminder
        await database.into(database.syncOutbox).insert(
              SyncOutboxCompanion.insert(
                id: uuid.v4(),
                entityType: 'reminder',
                entityId: reminderId,
                operation: 'create',
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        final success = await syncEngine.sync(userId: testUserId);
        expect(success, isTrue);

        // Verify both reminders and reminder_entity_links are populated remotely
        final remoteReminders = remoteClient.tables['reminders'];
        expect(remoteReminders, isNotNull);
        expect(remoteReminders!.first['id'], equals(reminderId));

        final remoteLinks = remoteClient.tables['reminder_entity_links'];
        expect(remoteLinks, isNotNull);
        expect(remoteLinks!.first['reminder_id'], equals(reminderId));
        expect(remoteLinks.first['entity_type'], equals('bill'));
        expect(remoteLinks.first['entity_id'], equals('bill-999'));
        expect(remoteLinks.first['user_id'], equals(testUserId));
      });

      test('processes individual person_role outbox entry cleanly without error', () async {
        final personId = uuid.v4();
        final now = DateTime.now().toUtc();

        await database.into(database.people).insert(
              PeopleCompanion.insert(
                id: personId,
                fullName: 'Alice Engineer',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await database.into(database.personRoles).insert(
              PersonRolesCompanion.insert(
                personId: personId,
                roleCode: 'engineer',
              ),
            );

        await database.into(database.syncOutbox).insert(
              SyncOutboxCompanion.insert(
                id: uuid.v4(),
                entityType: 'person_role',
                entityId: '${personId}_engineer',
                operation: 'create',
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        final success = await syncEngine.sync(userId: testUserId);
        expect(success, isTrue);

        final remoteRoles = remoteClient.tables['person_roles'];
        expect(remoteRoles, isNotNull);
        expect(remoteRoles!.first['person_id'], equals(personId));
        expect(remoteRoles.first['role_code'], equals('engineer'));
      });
    });
  });
}
