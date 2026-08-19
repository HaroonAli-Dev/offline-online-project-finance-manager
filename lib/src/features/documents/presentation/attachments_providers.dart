import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_provider.dart';
import '../data/attachments_repository.dart';
import '../domain/attachment_model.dart';

final attachmentsRepositoryProvider = Provider<AttachmentsRepository>((ref) {
  return AttachmentsRepository(ref.watch(appDatabaseProvider), const Uuid());
});

/// Watch all attachments for a specific entity.
/// Key is (entityType, entityId).
final entityAttachmentsProvider =
    StreamProvider.family<List<AttachmentModel>, (String, String)>((ref, key) {
      return ref
          .watch(attachmentsRepositoryProvider)
          .watchByEntity(key.$1, key.$2);
    });

/// Watch all attachments with optional category filter.
final allAttachmentsProvider =
    StreamProvider.family<List<AttachmentModel>, String?>((ref, category) {
      return ref
          .watch(attachmentsRepositoryProvider)
          .watchAll(categoryFilter: category);
    });
