import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/file_launcher_service.dart';
import '../data/attachment_picker_service.dart';
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
            Text('Attachments', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addAttachment(context, ref),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
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

  Future<void> _addAttachment(BuildContext context, WidgetRef ref) async {
    final picked = await AttachmentPickerService.pickFile();
    if (picked == null || !context.mounted) return;

    // Show description + category dialog
    final input = await showDialog<_AttachmentInput>(
      context: context,
      builder: (_) => _AttachmentInputDialog(
        fileName: picked.fileName,
        mimeType: picked.mimeType,
      ),
    );
    if (input == null || !context.mounted) return;

    final repo = ref.read(attachmentsRepositoryProvider);
    try {
      await repo.createAttachment(
        entityType: entityType,
        entityId: entityId,
        filePath: picked.filePath,
        fileName: picked.fileName,
        mimeType: picked.mimeType,
        category: input.category,
        description: input.description,
        capturedAt: DateTime.now().toUtc(),
        latitude: input.latitude,
        longitude: input.longitude,
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

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment, required this.onDelete});

  final AttachmentModel attachment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final icon = attachment.isPhoto
        ? Icons.image_outlined
        : attachment.category == 'receipt'
        ? Icons.receipt_outlined
        : attachment.category == 'document'
        ? Icons.description_outlined
        : Icons.attach_file;

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
          if (attachment.filePath != null)
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              tooltip: 'Open file',
              onPressed: () =>
                  FileLauncherService.openFile(attachment.filePath!),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Remove',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input dialog
// ---------------------------------------------------------------------------

class _AttachmentInput {
  const _AttachmentInput({
    required this.category,
    this.description,
    this.latitude,
    this.longitude,
  });

  final String category;
  final String? description;
  final double? latitude;
  final double? longitude;
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
              _AttachmentInput(
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
}
