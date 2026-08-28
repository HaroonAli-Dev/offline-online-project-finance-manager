import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';
import 'package:offline_finance_management_app/src/features/bills/data/bills_repository.dart';
import 'package:offline_finance_management_app/src/features/documents/data/attachments_repository.dart';

import 'package:offline_finance_management_app/src/features/schemes/data/schemes_repository.dart';
import 'package:offline_finance_management_app/src/features/sites/data/sites_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late SitesRepository sitesRepository;
  late SchemesRepository schemesRepository;
  late BillsRepository billsRepository;
  late AttachmentsRepository attachmentsRepository;

  /// Helper: create a scheme and return its id.
  Future<String> createScheme({String code = 'SCH-B01'}) async {
    await schemesRepository.createScheme(
      schemeCode: code,
      name: 'Bridge Construction $code',
      budget: 5000000.0,
      status: 'working',
      progressPercentage: 10.0,
    );
    final schemes = await schemesRepository.watchSchemes().first;
    return schemes.last.id;
  }

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    sitesRepository = SitesRepository(database, uuid);
    schemesRepository = SchemesRepository(database, uuid);
    billsRepository = BillsRepository(database, uuid);
    attachmentsRepository = AttachmentsRepository(database, uuid);
  });

  tearDown(() => database.close());

  // --------------------------------------------------------------------------
  // 1. Create bill
  // --------------------------------------------------------------------------
  test('creates a bill and reads it back', () async {
    final schemeId = await createScheme();

    await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'initial',
      billDate: DateTime(2026, 3, 1),
      amount: 100000.0,
      status: 'draft',
      remarks: 'First submission',
    );

    final bills = await billsRepository.watchBills().first;
    expect(bills, hasLength(1));
    final bill = bills.single;
    expect(bill.billType, 'initial');
    expect(bill.amount, 100000.0);
    expect(bill.status, 'draft');
    expect(bill.remarks, 'First submission');
    expect(bill.schemeId, schemeId);
  });

  test('new bill ID can immediately link an offline image and PDF attachment',
      () async {
    final schemeId = await createScheme(code: 'SCH-ATTACH');
    final billId = await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'initial',
      billDate: DateTime(2026, 3, 1),
      amount: 100000,
    );

    expect(billId, isNotEmpty);
    expect((await billsRepository.watchBills().first).single.id, billId);

    final imageId = await attachmentsRepository.createAttachment(
      entityType: 'bill',
      entityId: billId,
      filePath: '/offline/photo.jpg',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      fileSize: 123,
      category: 'photo',
      capturedAt: DateTime.now(),
    );
    final pdfId = await attachmentsRepository.createAttachment(
      entityType: 'bill',
      entityId: billId,
      filePath: '/offline/invoice.pdf',
      fileName: 'invoice.pdf',
      mimeType: 'application/pdf',
      fileSize: 456,
      category: 'document',
      capturedAt: DateTime.now(),
    );

    final attachments = await attachmentsRepository
        .watchByEntity('bill', billId)
        .first;
    expect(attachments.map((attachment) => attachment.id), containsAll([imageId, pdfId]));
    expect(attachments.every((attachment) => attachment.entityId == billId), isTrue);
    expect(attachments.every((attachment) => attachment.storagePath == null), isTrue);

    final outbox = await database.customSelect(
      "SELECT entity_type, entity_id FROM sync_outbox WHERE entity_type = 'attachment'",
    ).get();
    expect(outbox.map((row) => row.read<String>('entity_id')), containsAll([imageId, pdfId]));
  });

  // --------------------------------------------------------------------------
  // 2. Read bill with joined scheme + site names
  // --------------------------------------------------------------------------
  test('joins scheme name and site name on watch', () async {
    await sitesRepository.createSite(name: 'Lahore Site');
    final site = (await sitesRepository.watchSites().first).single;

    await schemesRepository.createScheme(
      schemeCode: 'SCH-J01',
      name: 'Joined Scheme',
      budget: 1000.0,
      siteId: site.id,
      status: 'working',
      progressPercentage: 0,
    );
    final scheme = (await schemesRepository.watchSchemes().first).single;

    await billsRepository.createBill(
      schemeId: scheme.id,
      billType: 'first',
      billDate: DateTime(2026, 4, 10),
      amount: 50000.0,
    );

    final bills = await billsRepository.watchBills().first;
    expect(bills.single.schemeName, 'Joined Scheme');
    expect(bills.single.siteName, 'Lahore Site');
  });

  // --------------------------------------------------------------------------
  // 3. Update bill
  // --------------------------------------------------------------------------
  test('updates an existing bill', () async {
    final schemeId = await createScheme();

    await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'initial',
      billDate: DateTime(2026, 3, 1),
      amount: 100000.0,
    );
    final original = (await billsRepository.watchBills().first).single;

    await billsRepository.updateBill(
      id: original.id,
      schemeId: schemeId,
      billType: 'first',
      billDate: DateTime(2026, 5, 15),
      amount: 200000.0,
      status: 'submitted',
      remarks: 'Updated after review',
    );

    final updated = (await billsRepository.watchBills().first).single;
    expect(updated.billType, 'first');
    expect(updated.amount, 200000.0);
    expect(updated.status, 'submitted');
    expect(updated.remarks, 'Updated after review');
  });

  // --------------------------------------------------------------------------
  // 4. Soft-delete bill
  // --------------------------------------------------------------------------
  test('soft-deletes a bill (deleted bill excluded from watch)', () async {
    final schemeId = await createScheme();

    await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'second',
      billDate: DateTime(2026, 6, 1),
      amount: 75000.0,
    );

    final before = await billsRepository.watchBills().first;
    expect(before, hasLength(1));

    await billsRepository.deleteBill(before.single.id);

    final after = await billsRepository.watchBills().first;
    expect(after, isEmpty);
  });

  // --------------------------------------------------------------------------
  // 5. Get bills by scheme
  // --------------------------------------------------------------------------
  test('watchBillsByScheme returns only bills for that scheme', () async {
    final schemeId1 = await createScheme(code: 'SCH-S01');
    final schemeId2 = await createScheme(code: 'SCH-S02');

    await billsRepository.createBill(
      schemeId: schemeId1,
      billType: 'initial',
      billDate: DateTime(2026, 1, 1),
      amount: 10000.0,
    );
    await billsRepository.createBill(
      schemeId: schemeId2,
      billType: 'first',
      billDate: DateTime(2026, 2, 1),
      amount: 20000.0,
    );

    final s1Bills = await billsRepository.watchBillsByScheme(schemeId1).first;
    expect(s1Bills, hasLength(1));
    expect(s1Bills.single.schemeId, schemeId1);

    final s2Bills = await billsRepository.watchBillsByScheme(schemeId2).first;
    expect(s2Bills, hasLength(1));
    expect(s2Bills.single.schemeId, schemeId2);
  });

  // --------------------------------------------------------------------------
  // 6. Search bills
  // --------------------------------------------------------------------------
  test('searchQuery filters bills by scheme name', () async {
    final schemeId = await createScheme(code: 'SCH-SR01');

    await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'initial',
      billDate: DateTime(2026, 1, 1),
      amount: 1000.0,
      remarks: 'Bridge deck work',
    );

    final match = await billsRepository
        .watchBills(searchQuery: 'Bridge Construction SCH-SR01')
        .first;
    expect(match, hasLength(1));

    final noMatch = await billsRepository
        .watchBills(searchQuery: 'XXXXXX')
        .first;
    expect(noMatch, isEmpty);
  });

  // --------------------------------------------------------------------------
  // 7. Filter by bill type
  // --------------------------------------------------------------------------
  test('typeFilter returns only matching bill type', () async {
    final schemeId = await createScheme();

    await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'initial',
      billDate: DateTime(2026, 1, 1),
      amount: 1000.0,
    );
    await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'final',
      billDate: DateTime(2026, 12, 1),
      amount: 9000.0,
    );

    final initial = await billsRepository
        .watchBills(typeFilter: 'initial')
        .first;
    expect(initial, hasLength(1));
    expect(initial.single.billType, 'initial');

    final finalBills = await billsRepository
        .watchBills(typeFilter: 'final')
        .first;
    expect(finalBills, hasLength(1));
    expect(finalBills.single.billType, 'final');
  });

  // --------------------------------------------------------------------------
  // 8. Filter by status
  // --------------------------------------------------------------------------
  test('statusFilter returns only matching status', () async {
    final schemeId = await createScheme();

    await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'initial',
      billDate: DateTime(2026, 1, 1),
      amount: 5000.0,
      status: 'draft',
    );
    await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'first',
      billDate: DateTime(2026, 3, 1),
      amount: 8000.0,
      status: 'paid',
    );

    final paid = await billsRepository.watchBills(statusFilter: 'paid').first;
    expect(paid, hasLength(1));
    expect(paid.single.status, 'paid');

    final draft = await billsRepository.watchBills(statusFilter: 'draft').first;
    expect(draft, hasLength(1));
    expect(draft.single.status, 'draft');
  });

  // --------------------------------------------------------------------------
  // 9. Amount stored and returned in paisa (integer internally)
  // --------------------------------------------------------------------------
  test(
    'amount is stored as integer paisa and returned as PKR correctly',
    () async {
      final schemeId = await createScheme();

      await billsRepository.createBill(
        schemeId: schemeId,
        billType: 'third',
        billDate: DateTime(2026, 8, 1),
        amount: 1234.56,
      );

      final raw = await database
          .customSelect('SELECT amount FROM bills WHERE deleted_at IS NULL')
          .getSingle();
      // stored as integer paisa
      expect(raw.read<int>('amount'), 123456);

      // returned as PKR
      final bills = await billsRepository.watchBills().first;
      expect(bills.single.amount, closeTo(1234.56, 0.001));
    },
  );

  // --------------------------------------------------------------------------
  // 10. Negative amount clamped to zero
  // --------------------------------------------------------------------------
  test('negative amount is clamped to zero', () async {
    final schemeId = await createScheme();

    await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'other',
      billDate: DateTime(2026, 8, 1),
      amount: -500.0,
    );

    final bills = await billsRepository.watchBills().first;
    expect(bills.single.amount, 0.0);
  });

  // --------------------------------------------------------------------------
  // 11. SyncOutbox entry created on create
  // --------------------------------------------------------------------------
  test('createBill enqueues a SyncOutbox entry', () async {
    final schemeId = await createScheme();

    await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'initial',
      billDate: DateTime(2026, 1, 1),
      amount: 50000.0,
    );

    final bill = (await billsRepository.watchBills().first).single;
    final outbox = await database
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='bill' AND entity_id=?",
          variables: [Variable.withString(bill.id)],
        )
        .get();
    expect(outbox, hasLength(1));
    expect(outbox.single.read<String>('operation'), 'create');
  });

  // --------------------------------------------------------------------------
  // 12. SyncOutbox entry created on update
  // --------------------------------------------------------------------------
  test('updateBill enqueues a SyncOutbox update entry', () async {
    final schemeId = await createScheme();

    await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'initial',
      billDate: DateTime(2026, 1, 1),
      amount: 50000.0,
    );
    final bill = (await billsRepository.watchBills().first).single;

    await billsRepository.updateBill(
      id: bill.id,
      schemeId: schemeId,
      billType: 'first',
      billDate: DateTime(2026, 2, 1),
      amount: 60000.0,
      status: 'submitted',
    );

    final outbox = await database
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='bill' AND entity_id=? AND operation='update'",
          variables: [Variable.withString(bill.id)],
        )
        .get();
    expect(outbox, hasLength(1));
  });

  // --------------------------------------------------------------------------
  // 13. SyncOutbox entry created on delete
  // --------------------------------------------------------------------------
  test('deleteBill enqueues a SyncOutbox delete entry', () async {
    final schemeId = await createScheme();

    await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'final',
      billDate: DateTime(2026, 12, 1),
      amount: 200000.0,
    );
    final bill = (await billsRepository.watchBills().first).single;

    await billsRepository.deleteBill(bill.id);

    final outbox = await database
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='bill' AND entity_id=? AND operation='delete'",
          variables: [Variable.withString(bill.id)],
        )
        .get();
    expect(outbox, hasLength(1));
  });

  // --------------------------------------------------------------------------
  // 14. Scheme relationship works correctly
  // --------------------------------------------------------------------------
  test('bill requires a valid scheme (FK enforced in query)', () async {
    final schemeId = await createScheme(code: 'SCH-FK01');

    await billsRepository.createBill(
      schemeId: schemeId,
      billType: 'initial',
      billDate: DateTime(2026, 1, 1),
      amount: 1000.0,
    );

    // Deleting the scheme soft-deletes it; bills JOIN excludes soft-deleted schemes
    await schemesRepository.deleteScheme(schemeId);
    final bills = await billsRepository.watchBills().first;
    expect(
      bills,
      isEmpty,
      reason: 'Bills for soft-deleted schemes should not appear',
    );
  });

  // --------------------------------------------------------------------------
  // 15. Bill totals calculated correctly
  // --------------------------------------------------------------------------
  test(
    'getBillTotals calculates totalBilled, totalPaid, outstanding',
    () async {
      final schemeId = await createScheme(code: 'SCH-T01');

      await billsRepository.createBill(
        schemeId: schemeId,
        billType: 'initial',
        billDate: DateTime(2026, 1, 1),
        amount: 100000.0,
        status: 'paid',
      );
      await billsRepository.createBill(
        schemeId: schemeId,
        billType: 'first',
        billDate: DateTime(2026, 3, 1),
        amount: 200000.0,
        status: 'approved',
      );
      await billsRepository.createBill(
        schemeId: schemeId,
        billType: 'second',
        billDate: DateTime(2026, 6, 1),
        amount: 150000.0,
        status: 'draft',
      );

      final totals = await billsRepository.getBillTotals(schemeId);
      expect(totals.totalBilled, closeTo(450000.0, 0.01));
      expect(totals.totalPaid, closeTo(100000.0, 0.01));
      expect(totals.outstanding, closeTo(350000.0, 0.01));
    },
  );

  // --------------------------------------------------------------------------
  // 16. BillTotals.zero for a scheme with no bills
  // --------------------------------------------------------------------------
  test('getBillTotals returns zeros for scheme with no bills', () async {
    final schemeId = await createScheme(code: 'SCH-EMPTY');

    final totals = await billsRepository.getBillTotals(schemeId);
    expect(totals.totalBilled, 0.0);
    expect(totals.totalPaid, 0.0);
    expect(totals.outstanding, 0.0);
  });

  // --------------------------------------------------------------------------
  // 17. Multiple bill types allowed per scheme
  // --------------------------------------------------------------------------
  test('a scheme can have multiple bills of different types', () async {
    final schemeId = await createScheme(code: 'SCH-MULTI');
    final types = ['initial', 'first', 'second', 'third', 'fourth', 'final'];
    for (final type in types) {
      await billsRepository.createBill(
        schemeId: schemeId,
        billType: type,
        billDate: DateTime(2026, 1, 1),
        amount: 10000.0,
      );
    }

    final bills = await billsRepository.watchBillsByScheme(schemeId).first;
    expect(bills, hasLength(types.length));
  });
}
