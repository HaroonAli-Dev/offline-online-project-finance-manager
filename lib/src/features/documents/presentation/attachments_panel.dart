import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/file_launcher_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/sync/sync_providers.dart';
import '../data/attachment_local_storage.dart';
import '../data/attachment_picker_service.dart';
import '../data/attachment_storage_service.dart';
import '../data/attachments_repository.dart';
import '../data/image_compression_service.dart';
import '../domain/attachment_draft.dart';
import '../domain/attachment_model.dart';
import 'attachments_providers.dart';

/// A self-contained panel that lists and manages attachments for any entity.
///
/// Embed this inside a Scheme detail page, Bill page, etc.:
/// ```dart
/// AttachmentsPanel(entityType: 'scheme', entityId: scheme.id)
/// ```
class AttachmentsPanel extends ConsumerWidget {
  const AttachmentsPanel({
    required this.entityType,
    required this.entityId,
    super.key,
  });

  final String entityType;
  final String entityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentsAsync = ref.watch(
      entityAttachmentsProvider((entityType, entityId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_file, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Attachments',
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            PopupMenuButton<AttachmentSource>(
              tooltip: 'Add attachment',
              onSelected: (source) => _addAttachment(context, ref, source),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: AttachmentSource.file,
                  child: Text('Choose document/file'),
                ),
                PopupMenuItem(
                  value: AttachmentSource.gallery,
                  child: Text('Choose photo'),
                ),
                PopupMenuItem(
                  value: AttachmentSource.camera,
                  child: Text('Take photo'),
                ),
              ],
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        attachmentsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No attachments yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            return Column(
              children: items
                  .map(
                    (a) => _AttachmentTile(
                      attachment: a,
                      onDelete: () => _delete(context, ref, a),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  Future<void> _addAttachment(
    BuildContext context,
    WidgetRef ref,
    AttachmentSource source,
  ) async {
    final draft = await pickAttachmentDraft(context, source);
    if (draft == null || !context.mounted) return;

    final repo = ref.read(attachmentsRepositoryProvider);
    try {
      await persistAttachmentDraft(
        repo: repo,
        draft: draft,
        entityType: entityType,
        entityId: entityId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Attachment saved.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving attachment: $e')));
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AttachmentModel a,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove attachment?'),
        content: Text(a.fileName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(attachmentsRepositoryProvider).deleteAttachment(a.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Attachment removed.')));
    }
  }
}

class _AttachmentTile extends ConsumerStatefulWidget {
  const _AttachmentTile({required this.attachment, required this.onDelete});

  final AttachmentModel attachment;
  final VoidCallback onDelete;

  @override
  ConsumerState<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends ConsumerState<_AttachmentTile> {
  bool _isDownloading = false;

  Future<void> _downloadAndOpen(BuildContext context) async {
    final storagePath = widget.attachment.storagePath;
    if (storagePath == null || storagePath.isEmpty) return;

    setState(() => _isDownloading = true);
    try {
      final storageClient = ref.read(attachmentStorageClientProvider);
      if (storageClient == null) {
        throw StateError('Supabase Storage is not configured or offline.');
      }
      final bytes = await storageClient.downloadBytes(
        bucket: AttachmentStorageService.defaultBucket,
        storagePath: storagePath,
      );
      final localPath = await saveAttachmentLocally(
        bytes,
        widget.attachment.fileName,
      );

      if (localPath != null) {
        final db = ref.read(appDatabaseProvider);
        await (db.update(db.attachments)
              ..where((t) => t.id.equals(widget.attachment.id)))
            .write(AttachmentsCompanion(filePath: Value(localPath)));
        if (context.mounted) {
          await FileLauncherService.openFile(localPath);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download attachment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    final icon = attachment.isPhoto
        ? Icons.image_outlined
        : attachment.category == 'receipt'
        ? Icons.receipt_outlined
        : attachment.category == 'document'
        ? Icons.description_outlined
        : Icons.attach_file;

    final hasLocalFile =
        attachment.filePath != null && attachment.filePath!.isNotEmpty;
    final hasCloudFile =
        attachment.storagePath != null && attachment.storagePath!.isNotEmpty;

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(attachment.fileName, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attachment.description != null)
            Text(attachment.description!, overflow: TextOverflow.ellipsis),
          if (attachment.hasGps)
            Text(
              'GPS: ${attachment.latitude!.toStringAsFixed(5)}, '
              '${attachment.longitude!.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 11),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isDownloading)
            const SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (hasLocalFile)
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              tooltip: 'Open file',
              onPressed: () => _openLocalAttachment(context, attachment),
            )
          else if (hasCloudFile)
            IconButton(
              icon: const Icon(Icons.cloud_download_outlined, size: 18),
              tooltip: 'Download from cloud',
              onPressed: () => _downloadAndOpen(context),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Remove',
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }

  Future<void> _openLocalAttachment(
    BuildContext context,
    AttachmentModel attachment,
  ) async {
    final reference = await createAttachmentObjectUrl(attachment.filePath);
    if (reference != null && context.mounted) {
      await FileLauncherService.openFile(reference);
    }
  }
}

enum AttachmentSource { file, gallery, camera }

Future<AttachmentDraft?> pickAttachmentDraft(
  BuildContext context,
  AttachmentSource source,
) async {
  final picked = switch (source) {
    AttachmentSource.file => await AttachmentPickerService.pickFile(),
    AttachmentSource.gallery => await AttachmentPickerService.selectPhoto(),
    AttachmentSource.camera => await AttachmentPickerService.takePhoto(),
  };
  if (picked == null || !context.mounted) return null;

  final input = await showDialog<AttachmentInput>(
    context: context,
    builder: (_) => _AttachmentInputDialog(
      fileName: picked.fileName,
      mimeType: picked.mimeType,
    ),
  );
  if (input == null || !context.mounted) return null;
  return AttachmentDraft(file: picked, input: input);
}

Future<void> persistAttachmentDraft({
  required AttachmentsRepository repo,
  required AttachmentDraft draft,
  required String entityType,
  required String entityId,
}) async {
  var bytes = draft.file.bytes;
  var fileName = draft.file.fileName;
  var mimeType = draft.file.mimeType;
  int? width;
  int? height;
  if ((mimeType ?? '').startsWith('image/') && bytes != null) {
    final image = ImageCompressionService.process(bytes);
    bytes = image.bytes;
    mimeType = image.mimeType;
    fileName = '${fileName.split('.').first}.jpg';
    width = image.width;
    height = image.height;
  }
  final storedPath = bytes == null
      ? draft.file.filePath
      : await saveAttachmentLocally(bytes, fileName);
  await repo.createAttachment(
    entityType: entityType,
    entityId: entityId,
    filePath: storedPath,
    fileName: fileName,
    mimeType: mimeType,
    fileSize: bytes?.length ?? draft.file.size,
    imageWidth: width,
    imageHeight: height,
    category: draft.input.category,
    description: draft.input.description,
    capturedAt: DateTime.now().toUtc(),
    latitude: draft.input.latitude,
    longitude: draft.input.longitude,
  );
}

class _AttachmentInputDialog extends StatefulWidget {
  const _AttachmentInputDialog({required this.fileName, this.mimeType});

  final String fileName;
  final String? mimeType;

  @override
  State<_AttachmentInputDialog> createState() => _AttachmentInputDialogState();
}

class _AttachmentInputDialogState extends State<_AttachmentInputDialog> {
  final _descController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String _category = 'other';
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    // Auto-detect category from MIME
    final mime = widget.mimeType ?? '';
    if (mime.startsWith('image/')) {
      _category = 'photo';
    } else if (mime == 'application/pdf' ||
        mime.contains('word') ||
        mime.contains('sheet')) {
      _category = 'document';
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Attachment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.fileName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              initialValue: _category,
              items: kAttachmentCategories
                  .map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _gettingLocation ? null : _captureLocation,
                icon: _gettingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('Use current location'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              AttachmentInput(
                category: _category,
                description: _descController.text.trim().isEmpty
                    ? null
                    : _descController.text.trim(),
                latitude: double.tryParse(_latController.text),
                longitude: double.tryParse(_lngController.text),
              ),
            );
          },
          child: const Text('SAVE'),
        ),
      ],
    );
  }

  Future<void> _captureLocation() async {
    setState(() => _gettingLocation = true);
    final result = await LocationService.currentLocation();
    if (!mounted) return;
    setState(() => _gettingLocation = false);
    if (result.isSuccess) {
      _latController.text = result.latitude!.toStringAsFixed(6);
      _lngController.text = result.longitude!.toStringAsFixed(6);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Location is unavailable.')),
      );
    }
  }
}
