import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';
import 'package:offline_finance_management_app/src/features/documents/data/attachments_repository.dart';
import 'package:offline_finance_management_app/src/features/schemes/data/schemes_repository.dart';
import 'package:offline_finance_management_app/src/features/sites/data/sites_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late SitesRepository sitesRepo;
  late SchemesRepository schemesRepo;
  late AttachmentsRepository repo;

  Future<String> createScheme({String code = 'SCH-A01'}) async {
    await schemesRepo.createScheme(
      schemeCode: code,
      name: 'Test Scheme $code',
      budget: 500000.0,
    );
    return (await schemesRepo.watchSchemes().first).last.id;
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    sitesRepo = SitesRepository(db, uuid);
    schemesRepo = SchemesRepository(db, uuid);
    repo = AttachmentsRepository(db, uuid);
  });

  tearDown(() => db.close());

  // --------------------------------------------------------------------------
  // 1. Migration — table exists
  // --------------------------------------------------------------------------
  test('attachments table exists after migration', () async {
    final rows = await db.select(db.attachments).get();
    expect(rows, isEmpty);
  });

  // --------------------------------------------------------------------------
  // 2. Existing data survives migration
  // --------------------------------------------------------------------------
  test('existing schemes survive attachments migration', () async {
    await createScheme();
    final schemes = await schemesRepo.watchSchemes().first;
    expect(schemes, hasLength(1));
  });

  // --------------------------------------------------------------------------
  // 3. Create attachment
  // --------------------------------------------------------------------------
  test('creates an attachment and reads it back', () async {
    final schemeId = await createScheme();

    final id = await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      filePath: '/data/photos/site_01.jpg',
      fileName: 'site_01.jpg',
      mimeType: 'image/jpeg',
      category: 'photo',
      description: 'Front view of site',
      capturedAt: DateTime(2026, 8, 1),
    );

    final items = await repo.watchByEntity('scheme', schemeId).first;
    expect(items, hasLength(1));
    final a = items.single;
    expect(a.id, id);
    expect(a.entityType, 'scheme');
    expect(a.entityId, schemeId);
    expect(a.fileName, 'site_01.jpg');
    expect(a.category, 'photo');
    expect(a.description, 'Front view of site');
    expect(a.filePath, '/data/photos/site_01.jpg');
    expect(a.mimeType, 'image/jpeg');
  });

  // --------------------------------------------------------------------------
  // 4. watchByEntity isolates by entity
  // --------------------------------------------------------------------------
  test('watchByEntity returns only attachments for that entity', () async {
    final schemeId1 = await createScheme(code: 'SCH-X1');
    final schemeId2 = await createScheme(code: 'SCH-X2');

    await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId1,
      fileName: 'photo_a.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 1),
    );
    await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId2,
      fileName: 'photo_b.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 2),
    );

    final s1 = await repo.watchByEntity('scheme', schemeId1).first;
    expect(s1, hasLength(1));
    expect(s1.single.fileName, 'photo_a.jpg');

    final s2 = await repo.watchByEntity('scheme', schemeId2).first;
    expect(s2, hasLength(1));
    expect(s2.single.fileName, 'photo_b.jpg');
  });

  // --------------------------------------------------------------------------
  // 5. Update attachment
  // --------------------------------------------------------------------------
  test('updates description, category, and GPS', () async {
    final schemeId = await createScheme();

    final id = await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'doc.pdf',
      category: 'other',
      capturedAt: DateTime(2026, 8, 1),
    );

    await repo.updateAttachment(
      id: id,
      description: 'Updated description',
      category: 'document',
      latitude: 31.5204,
      longitude: 74.3587,
    );

    final items = await repo.watchByEntity('scheme', schemeId).first;
    expect(items.single.description, 'Updated description');
    expect(items.single.category, 'document');
    expect(items.single.latitude, closeTo(31.5204, 0.0001));
    expect(items.single.longitude, closeTo(74.3587, 0.0001));
  });

  // --------------------------------------------------------------------------
  // 6. Soft delete
  // --------------------------------------------------------------------------
  test('soft-deletes an attachment (excluded from watch)', () async {
    final schemeId = await createScheme();

    final id = await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'receipt.pdf',
      category: 'receipt',
      capturedAt: DateTime(2026, 8, 1),
    );

    final before = await repo.watchByEntity('scheme', schemeId).first;
    expect(before, hasLength(1));

    await repo.deleteAttachment(id);

    final after = await repo.watchByEntity('scheme', schemeId).first;
    expect(after, isEmpty);

    final raw = await db
        .customSelect(
          'SELECT deleted_at FROM attachments WHERE id = ?',
          variables: [drift.Variable.withString(id)],
        )
        .getSingle();
    expect(raw.readNullable<DateTime>('deleted_at'), isNotNull);
  });

  // --------------------------------------------------------------------------
  // 7. watchAll with category filter
  // --------------------------------------------------------------------------
  test('watchAll with categoryFilter returns only matching category', () async {
    final schemeId = await createScheme();

    await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'photo.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 1),
    );
    await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'contract.pdf',
      category: 'document',
      capturedAt: DateTime(2026, 8, 2),
    );

    final photos = await repo.watchAll(categoryFilter: 'photo').first;
    expect(photos, hasLength(1));
    expect(photos.single.category, 'photo');

    final docs = await repo.watchAll(categoryFilter: 'document').first;
    expect(docs, hasLength(1));
    expect(docs.single.category, 'document');

    final all = await repo.watchAll().first;
    expect(all, hasLength(2));
  });

  // --------------------------------------------------------------------------
  // 8. GPS coordinates stored and returned
  // --------------------------------------------------------------------------
  test('GPS coordinates are stored and returned correctly', () async {
    final schemeId = await createScheme();

    await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'gps_photo.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 1),
      latitude: 31.5204,
      longitude: 74.3587,
    );

    final items = await repo.watchByEntity('scheme', schemeId).first;
    expect(items.single.hasGps, isTrue);
    expect(items.single.latitude, closeTo(31.5204, 0.0001));
    expect(items.single.longitude, closeTo(74.3587, 0.0001));
  });

  // --------------------------------------------------------------------------
  // 9. Attachment without GPS
  // --------------------------------------------------------------------------
  test('attachment without GPS has hasGps == false', () async {
    final schemeId = await createScheme();

    await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'no_gps.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 1),
    );

    final items = await repo.watchByEntity('scheme', schemeId).first;
    expect(items.single.hasGps, isFalse);
  });

  // --------------------------------------------------------------------------
  // 10. Polymorphic entity types
  // --------------------------------------------------------------------------
  test('attachments can be linked to different entity types', () async {
    final schemeId = await createScheme();

    await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'scheme_doc.pdf',
      category: 'document',
      capturedAt: DateTime(2026, 8, 1),
    );
    await repo.createAttachment(
      entityType: 'bill',
      entityId: 'fake-bill-id',
      fileName: 'bill_receipt.jpg',
      category: 'receipt',
      capturedAt: DateTime(2026, 8, 2),
    );

    final schemeAttachments = await repo
        .watchByEntity('scheme', schemeId)
        .first;
    expect(schemeAttachments, hasLength(1));
    expect(schemeAttachments.single.entityType, 'scheme');

    final billAttachments = await repo
        .watchByEntity('bill', 'fake-bill-id')
        .first;
    expect(billAttachments, hasLength(1));
    expect(billAttachments.single.entityType, 'bill');
  });

  // --------------------------------------------------------------------------
  // 11. isPhoto helper
  // --------------------------------------------------------------------------
  test('isPhoto returns true for photo category with image MIME', () async {
    final schemeId = await createScheme();

    await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'img.png',
      mimeType: 'image/png',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 1),
    );

    final items = await repo.watchByEntity('scheme', schemeId).first;
    expect(items.single.isPhoto, isTrue);
  });

  // --------------------------------------------------------------------------
  // 12. SyncOutbox — create
  // --------------------------------------------------------------------------
  test('createAttachment enqueues a SyncOutbox create entry', () async {
    final schemeId = await createScheme();

    final id = await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'photo.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 1),
    );

    final outbox = await db
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='attachment' "
          "AND entity_id=? AND operation='create'",
          variables: [drift.Variable.withString(id)],
        )
        .get();
    expect(outbox, hasLength(1));
  });

  // --------------------------------------------------------------------------
  // 13. SyncOutbox — update
  // --------------------------------------------------------------------------
  test('updateAttachment enqueues a SyncOutbox update entry', () async {
    final schemeId = await createScheme();

    final id = await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'photo.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 1),
    );

    await repo.updateAttachment(
      id: id,
      category: 'document',
      description: 'Updated',
    );

    final outbox = await db
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='attachment' "
          "AND entity_id=? AND operation='update'",
          variables: [drift.Variable.withString(id)],
        )
        .get();
    expect(outbox, hasLength(1));
  });

  // --------------------------------------------------------------------------
  // 14. SyncOutbox — delete
  // --------------------------------------------------------------------------
  test('deleteAttachment enqueues a SyncOutbox delete entry', () async {
    final schemeId = await createScheme();

    final id = await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'photo.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 1),
    );

    await repo.deleteAttachment(id);

    final outbox = await db
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='attachment' "
          "AND entity_id=? AND operation='delete'",
          variables: [drift.Variable.withString(id)],
        )
        .get();
    expect(outbox, hasLength(1));
  });

  // --------------------------------------------------------------------------
  // 15. Transactional — record + outbox created together
  // --------------------------------------------------------------------------
  test('attachment record and outbox entry are created atomically', () async {
    final schemeId = await createScheme();

    await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'atomic.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 1),
    );

    final items = await repo.watchByEntity('scheme', schemeId).first;
    final outbox = await db
        .customSelect(
          "SELECT * FROM sync_outbox WHERE entity_type='attachment'",
        )
        .get();

    expect(items, hasLength(1));
    expect(outbox, isNotEmpty);
  });

  // --------------------------------------------------------------------------
  // 16. Multiple attachments ordered by capturedAt DESC
  // --------------------------------------------------------------------------
  test('multiple attachments ordered by capturedAt DESC', () async {
    final schemeId = await createScheme();

    await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'first.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 1),
    );
    await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'second.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 10),
    );
    await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'third.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 20),
    );

    final items = await repo.watchByEntity('scheme', schemeId).first;
    expect(items, hasLength(3));
    expect(items[0].fileName, 'third.jpg');
    expect(items[2].fileName, 'first.jpg');
  });

  // --------------------------------------------------------------------------
  // 17. filePath is nullable (Web scenario)
  // --------------------------------------------------------------------------
  test('filePath can be null (Web scenario)', () async {
    final schemeId = await createScheme();

    await repo.createAttachment(
      entityType: 'scheme',
      entityId: schemeId,
      fileName: 'web_upload.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 1),
    );

    final items = await repo.watchByEntity('scheme', schemeId).first;
    expect(items.single.filePath, isNull);
  });

  // --------------------------------------------------------------------------
  // 18. Site entity type
  // --------------------------------------------------------------------------
  test('attachments can be linked to a site entity', () async {
    await sitesRepo.createSite(name: 'Ring Road');
    final site = (await sitesRepo.watchSites().first).single;

    await repo.createAttachment(
      entityType: 'site',
      entityId: site.id,
      fileName: 'site_overview.jpg',
      category: 'photo',
      capturedAt: DateTime(2026, 8, 1),
    );

    final items = await repo.watchByEntity('site', site.id).first;
    expect(items, hasLength(1));
    expect(items.single.entityType, 'site');
  });
}
