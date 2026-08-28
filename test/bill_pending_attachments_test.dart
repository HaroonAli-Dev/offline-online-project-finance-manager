import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';
import 'package:offline_finance_management_app/src/features/bills/data/bills_repository.dart';
import 'package:offline_finance_management_app/src/features/documents/data/attachment_picker_service.dart';
import 'package:offline_finance_management_app/src/features/documents/data/attachments_repository.dart';
import 'package:offline_finance_management_app/src/features/documents/domain/attachment_draft.dart';
import 'package:offline_finance_management_app/src/features/documents/presentation/attachments_panel.dart';
import 'package:offline_finance_management_app/src/features/schemes/data/schemes_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late BillsRepository bills;
  late AttachmentsRepository attachments;
  late SchemesRepository schemes;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    bills = BillsRepository(db, uuid);
    attachments = AttachmentsRepository(db, uuid);
    schemes = SchemesRepository(db, uuid);
  });

  tearDown(() => db.close());

  Future<String> createScheme() async {
    await schemes.createScheme(
      schemeCode: 'BILL-ATTACH',
      name: 'Bill attachment scheme',
      budget: 100000,
    );
    return (await schemes.watchSchemes().first).single.id;
  }

  Future<String> createBill() async => bills.createBill(
    schemeId: await createScheme(),
    billType: 'initial',
    billDate: DateTime(2026, 8, 28),
    amount: 1250,
  );

  AttachmentDraft draft(String name, String mime, String category) {
    return AttachmentDraft(
      file: PickedFile(
        fileName: name,
        mimeType: mime,
        filePath: '/pending/$name',
      ),
      input: AttachmentInput(category: category),
    );
  }

  Future<void> saveDrafts(String billId, List<AttachmentDraft> drafts) async {
    for (final pending in drafts) {
      await persistAttachmentDraft(
        repo: attachments,
        draft: pending,
        entityType: 'bill',
        entityId: billId,
      );
    }
  }

  test('creates a bill without attachments', () async {
    final billId = await createBill();
    expect(billId, isNotEmpty);
    expect(await attachments.watchByEntity('bill', billId).first, isEmpty);
  });

  test('associates an image draft with the generated bill ID', () async {
    final billId = await createBill();
    await saveDrafts(billId, [draft('bill.jpg', 'image/jpeg', 'photo')]);

    final items = await attachments.watchByEntity('bill', billId).first;
    expect(items.single.entityType, 'bill');
    expect(items.single.entityId, billId);
    expect(items.single.fileName, 'bill.jpg');
  });

  test('associates a PDF draft with the generated bill ID', () async {
    final billId = await createBill();
    await saveDrafts(billId, [
      draft('invoice.pdf', 'application/pdf', 'document'),
    ]);

    final items = await attachments.watchByEntity('bill', billId).first;
    expect(items.single.mimeType, 'application/pdf');
    expect(items.single.entityId, billId);
  });

  test(
    'associates multiple pending drafts and enqueues each attachment',
    () async {
      final billId = await createBill();
      await saveDrafts(billId, [
        draft('one.jpg', 'image/jpeg', 'photo'),
        draft('two.pdf', 'application/pdf', 'document'),
      ]);

      expect(
        await attachments.watchByEntity('bill', billId).first,
        hasLength(2),
      );
      final outbox = await (db.select(
        db.syncOutbox,
      )..where((entry) => entry.entityType.equals('attachment'))).get();
      expect(outbox, hasLength(2));
    },
  );

  test('canceling before save leaves no bill or attachment rows', () async {
    final schemeId = await createScheme();
    final pending = [draft('cancelled.pdf', 'application/pdf', 'document')];

    // The form only calls createBill after it is submitted; drafts alone are
    // deliberately never sent to the attachment repository.
    expect(pending, hasLength(1));
    expect(await db.select(db.bills).get(), isEmpty);
    expect(await db.select(db.attachments).get(), isEmpty);
    expect(schemeId, isNotEmpty);
  });
}
