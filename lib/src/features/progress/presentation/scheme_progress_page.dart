import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../schemes/domain/scheme_model.dart';
import '../domain/progress_model.dart';
import 'progress_form_dialog.dart';
import 'progress_providers.dart';

class SchemeProgressPage extends ConsumerWidget {
  const SchemeProgressPage({required this.scheme, super.key});

  final SchemeModel scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updatesAsync = ref.watch(schemeProgressProvider(scheme.id));

    return Scaffold(
      appBar: AppBar(title: Text('Progress: ${scheme.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProgressForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Progress'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryHeader(scheme: scheme),
          const Divider(height: 1),
          Expanded(
            child: updatesAsync.when(
              data: (updates) {
                if (updates.isEmpty) {
                  return const Center(child: Text('No progress updates yet.'));
                }
                return ListView.separated(
                  itemCount: updates.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final u = updates[index];
                    return _ProgressHistoryTile(
                      update: u,
                      onEdit: () => _showProgressForm(context, ref, update: u),
                      onDelete: () => _confirmDelete(context, ref, u),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProgressForm(
    BuildContext context,
    WidgetRef ref, {
    ProgressModel? update,
  }) async {
    final input = await showDialog<ProgressInput>(
      context: context,
      builder: (_) => ProgressFormDialog(
        progress: update,
        schemes: [scheme],
        preselectedSchemeId: scheme.id,
      ),
    );

    if (input == null || !context.mounted) return;

    final repo = ref.read(progressRepositoryProvider);
    try {
      if (update == null) {
        await repo.createProgress(
          schemeId: input.schemeId,
          siteId: input.siteId,
          status: input.status,
          progressPercentage: input.progressPercentage,
          date: input.date,
          incompleteReason: input.incompleteReason,
          result: input.result,
          remarks: input.remarks,
        );
      } else {
        await repo.updateProgress(
          id: update.id,
          schemeId: input.schemeId,
          siteId: input.siteId,
          status: input.status,
          progressPercentage: input.progressPercentage,
          date: input.date,
          incompleteReason: input.incompleteReason,
          result: input.result,
          remarks: input.remarks,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              update == null
                  ? 'Progress update added.'
                  : 'Progress update saved.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving progress: $e')));
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ProgressModel update,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete progress update?'),
        content: Text(
          '${update.statusDisplay} on ${update.date.toLocal().toString().split(' ')[0]} will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(progressRepositoryProvider).deleteProgress(update.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress update deleted.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error deleting: $e')));
      }
    }
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.scheme});
  final SchemeModel scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current: ${scheme.statusDisplay} (${scheme.progressPercentage.round()}%)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (scheme.result != null) ...[
            const SizedBox(height: 4),
            Text('Latest Result: ${scheme.result}'),
          ],
          if (scheme.incompleteReason != null) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: ${scheme.incompleteReason}',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressHistoryTile extends StatelessWidget {
  const _ProgressHistoryTile({
    required this.update,
    required this.onEdit,
    required this.onDelete,
  });

  final ProgressModel update;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateStr = update.date.toLocal().toString().split(' ')[0];
    final color = switch (update.status) {
      'working' => Colors.indigo,
      'in_progress' => Colors.blue,
      'completed' => Colors.green,
      'incomplete' => Colors.red,
      _ => Colors.grey,
    };

    return ListTile(
      leading: CircleAvatar(
        radius: 10,
        backgroundColor: color.withValues(alpha: 0.2),
        child: Icon(Icons.circle, size: 10, color: color),
      ),
      title: Text('${update.statusDisplay} — ${update.percentageDisplay}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr),
          if (update.result != null) Text('Result: ${update.result}'),
          if (update.incompleteReason != null)
            Text(
              'Reason: ${update.incompleteReason}',
              style: const TextStyle(color: Colors.red),
            ),
          if (update.remarks != null) Text('Remarks: ${update.remarks}'),
        ],
      ),
      trailing: PopupMenuButton<_Action>(
        onSelected: (action) => switch (action) {
          _Action.edit => onEdit(),
          _Action.delete => onDelete(),
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: _Action.edit, child: Text('Edit')),
          PopupMenuItem(value: _Action.delete, child: Text('Delete')),
        ],
      ),
    );
  }
}

enum _Action { edit, delete }
