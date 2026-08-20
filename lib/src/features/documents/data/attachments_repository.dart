import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/attachment_model.dart';

class AttachmentsRepository {
  AttachmentsRepository(this._db, this._uuid);

  final AppDatabase _db;
  final Uuid _uuid;

  // ---------------------------------------------------------------------------
  // Watch / Query
  // ---------------------------------------------------------------------------

  /// Watch all attachments for a specific entity (e.g. a scheme or bill).
  Stream<List<AttachmentModel>> watchByEntity(
    String entityType,
    String entityId,
  ) {
    const sql = '''
      SELECT id, entity_type, entity_id, file_path, file_name, mime_type, file_size, image_width, image_height,
             category, description, captured_at, latitude, longitude
      FROM attachments
      WHERE deleted_at IS NULL
        AND entity_type = ?
        AND entity_id   = ?
      ORDER BY captured_at DESC, created_at DESC
    ''';

    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withString(entityType),
            Variable.withString(entityId),
          ],
          readsFrom: {_db.attachments},
        )
        .watch()
        .map((rows) => rows.map(_fromRow).toList());
  }

  /// Watch all attachments, optionally filtered by category.
  Stream<List<AttachmentModel>> watchAll({String? categoryFilter}) {
    final cleanCategory = categoryFilter?.trim() ?? '';

    const sql = '''
      SELECT id, entity_type, entity_id, file_path, file_name, mime_type, file_size, image_width, image_height,
             category, description, captured_at, latitude, longitude
      FROM attachments
      WHERE deleted_at IS NULL
        AND (? = '' OR category = ?)
      ORDER BY captured_at DESC, created_at DESC
    ''';

    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withString(cleanCategory),
            Variable.withString(cleanCategory),
          ],
          readsFrom: {_db.attachments},
        )
        .watch()
        .map((rows) => rows.map(_fromRow).toList());
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<String> createAttachment({
    required String entityType,
    required String entityId,
    String? filePath,
    required String fileName,
    String? mimeType,
    int? fileSize,
    int? imageWidth,
    int? imageHeight,
    String category = 'other',
    String? description,
    required DateTime capturedAt,
    double? latitude,
    double? longitude,
  }) async {
    if (!hasValidCoordinates(latitude, longitude)) {
      throw ArgumentError('Latitude must be -90..90 and longitude -180..180.');
    }
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      await _db
          .into(_db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: id,
              entityType: entityType,
              entityId: entityId,
              filePath: Value(_cleanOptional(filePath)),
              fileName: fileName.trim(),
              mimeType: Value(_cleanOptional(mimeType)),
              fileSize: Value(fileSize),
              imageWidth: Value(imageWidth),
              imageHeight: Value(imageHeight),
              category: Value(
                category.trim().isEmpty ? 'other' : category.trim(),
              ),
              description: Value(_cleanOptional(description)),
              capturedAt: capturedAt.toUtc(),
              latitude: Value(latitude),
              longitude: Value(longitude),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueueChange('attachment', id, 'create', now);
    });

    return id;
  }

  Future<void> updateAttachment({
    required String id,
    String? description,
    required String category,
    double? latitude,
    double? longitude,
  }) async {
    if (!hasValidCoordinates(latitude, longitude)) {
      throw ArgumentError('Latitude must be -90..90 and longitude -180..180.');
    }
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      await (_db.update(_db.attachments)..where((a) => a.id.equals(id))).write(
        AttachmentsCompanion(
          description: Value(_cleanOptional(description)),
          category: Value(category.trim()),
          latitude: Value(latitude),
          longitude: Value(longitude),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _enqueueChange('attachment', id, 'update', now);
    });
  }

  Future<void> deleteAttachment(String id) async {
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      await (_db.update(_db.attachments)..where((a) => a.id.equals(id))).write(
        AttachmentsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pendingDelete.databaseValue),
        ),
      );
      await _enqueueChange('attachment', id, 'delete', now);
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
        await (_db.select(_db.syncOutbox)..where(
              (e) =>
                  e.entityType.equals(entityType) &
                  e.entityId.equals(entityId) &
                  e.operation.equals(operation),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (_db.update(
        _db.syncOutbox,
      )..where((e) => e.id.equals(existing.id))).write(
        SyncOutboxCompanion(
          updatedAt: Value(now),
          attemptCount: const Value(0),
          nextAttemptAt: const Value(null),
          lastError: const Value(null),
        ),
      );
    } else {
      await _db
          .into(_db.syncOutbox)
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

  AttachmentModel _fromRow(QueryRow row) {
    return AttachmentModel(
      id: row.read<String>('id'),
      entityType: row.read<String>('entity_type'),
      entityId: row.read<String>('entity_id'),
      filePath: row.readNullable<String>('file_path'),
      fileName: row.read<String>('file_name'),
      mimeType: row.readNullable<String>('mime_type'),
      fileSize: row.readNullable<int>('file_size'),
      imageWidth: row.readNullable<int>('image_width'),
      imageHeight: row.readNullable<int>('image_height'),
      category: row.read<String>('category'),
      description: row.readNullable<String>('description'),
      capturedAt: row.read<DateTime>('captured_at'),
      latitude: row.readNullable<double>('latitude'),
      longitude: row.readNullable<double>('longitude'),
    );
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static bool hasValidCoordinates(double? latitude, double? longitude) {
    if (latitude == null && longitude == null) return true;
    if (latitude == null || longitude == null) return false;
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
