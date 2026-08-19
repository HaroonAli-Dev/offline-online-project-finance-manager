import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/hint_banner.dart';
import '../../schemes/domain/scheme_model.dart';
import 'progress_form_dialog.dart';
import 'progress_providers.dart';
import '../domain/progress_model.dart';

class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updatesAsync = ref.watch(progressListProvider);
    final allSchemes = ref.watch(progressAllSchemesProvider);
    final selectedScheme = ref.watch(progressSchemeFilterProvider);
    final selectedStatus = ref.watch(progressStatusFilterProvider);

    const hint = HintBanner(
      pageKey: 'progress',
      icon: Icons.track_changes,
      hints: [
        'Track physical progress of your construction schemes.',
        'Adding a progress update automatically updates the parent scheme\'s status.',
        'View the full history of a scheme\'s progress via "View Progress" on a Scheme card.',
      ],
    );

    final filters = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: (val) =>
                ref.read(progressSearchQueryProvider.notifier).state = val,
            decoration: const InputDecoration(
              labelText: 'Search',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<SchemeModel?>(
            decoration: const InputDecoration(
              labelText: 'Scheme',
              border: OutlineInputBorder(),
            ),
            initialValue: selectedScheme,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Schemes')),
              ...allSchemes.map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text('${s.schemeCode} – ${s.name}'),
                ),
              ),
            ],
            onChanged: (val) =>
                ref.read(progressSchemeFilterProvider.notifier).state = val,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            initialValue: selectedStatus,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Statuses')),
              ...kProgressStatuses.map(
                (s) => DropdownMenuItem(value: s.$1, child: Text(s.$2)),
              ),
            ],
            onChanged: (val) =>
                ref.read(progressStatusFilterProvider.notifier).state = val,
          ),
        ],
      ),
    );

    final list = updatesAsync.when(
      data: (updates) {
        if (updates.isEmpty) {
          return const Center(child: Text('No progress updates found.'));
        }
        return ListView.separated(
          itemCount: updates.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final update = updates[index];
            return _ProgressTile(
              update: update,
              onEdit: () => _showProgressForm(context, ref, update: update),
              onDelete: () => _confirmDelete(context, ref, update),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Progress Tracking')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProgressForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Progress'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 700) {
            return Column(
              children: [
                hint,
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 280,
                        child: SingleChildScrollView(child: filters),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: list),
                    ],
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [hint, filters],
                ),
              ),
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showProgressForm(
    BuildContext context,
    WidgetRef ref, {
    ProgressModel? update,
  }) async {
    final allSchemes = ref.read(progressAllSchemesProvider);
    if (allSchemes.isEmpty && update == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No schemes available to track.')),
      );
      return;
    }

    final input = await showDialog<ProgressInput>(
      context: context,
      builder: (_) => ProgressFormDialog(progress: update, schemes: allSchemes),
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

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({
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
    return ListTile(
      leading: _StatusDot(status: update.status),
      title: Text(
        '${update.schemeName} — ${update.statusDisplay} (${update.percentageDisplay})',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr),
          if (update.siteName != null) Text('Site: ${update.siteName}'),
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

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'working' => Colors.indigo,
      'in_progress' => Colors.blue,
      'completed' => Colors.green,
      'incomplete' => Colors.red,
      _ => Colors.grey,
    };
    return CircleAvatar(
      radius: 10,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Icon(Icons.circle, size: 10, color: color),
    );
  }
}

enum _Action { edit, delete }
