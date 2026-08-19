import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../schemes/presentation/schemes_providers.dart';
import '../../sites/presentation/sites_providers.dart';
import '../data/reminders_repository.dart';
import '../domain/reminder_model.dart';
import 'reminders_providers.dart';

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  static const _wideLayoutBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    final schemes = ref.watch(schemesProvider).valueOrNull ?? const [];
    final sites = ref.watch(sitesProvider).valueOrNull ?? const [];
    final selectedPriority = ref.watch(remindersPriorityFilterProvider);
    final selectedDone = ref.watch(remindersDoneFilterProvider);
    final repository = ref.read(remindersRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReminderForm(context, repository, schemes, sites),
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Add Reminder'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;

          final filters = _RemindersFilters(
            selectedPriority: selectedPriority,
            selectedDone: selectedDone,
            onPrioritySelected: (p) =>
                ref.read(remindersPriorityFilterProvider.notifier).state = p,
            onDoneSelected: (d) =>
                ref.read(remindersDoneFilterProvider.notifier).state = d,
            onSearchChanged: (v) =>
                ref.read(remindersSearchProvider.notifier).state = v,
            isWide: isWide,
          );

          final list = reminders.when(
            data: (items) => _RemindersList(
              items: items,
              repository: repository,
              schemes: schemes,
              sites: sites,
              isWide: isWide,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Unable to load reminders: $e')),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 280, child: filters),
                const VerticalDivider(width: 1),
                Expanded(child: list),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(child: filters),
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Show form helper
// ---------------------------------------------------------------------------

Future<void> _showReminderForm(
  BuildContext context,
  RemindersRepository repository,
  List<dynamic> schemes,
  List<dynamic> sites, {
  ReminderModel? reminder,
}) async {
  final input = await showDialog<_ReminderInput>(
    context: context,
    builder: (_) => _ReminderFormDialog(
      reminder: reminder,
      schemes: schemes.cast(),
      sites: sites.cast(),
    ),
  );
  if (input == null || !context.mounted) return;

  try {
    if (reminder == null) {
      await repository.createReminder(
        title: input.title,
        description: input.description,
        dueAt: input.dueAt,
        priority: input.priority,
        schemeId: input.schemeId,
        siteId: input.siteId,
        remarks: input.remarks,
      );
    } else {
      await repository.updateReminder(
        id: reminder.id,
        title: input.title,
        description: input.description,
        dueAt: input.dueAt,
        priority: input.priority,
        schemeId: input.schemeId,
        siteId: input.siteId,
        remarks: input.remarks,
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reminder == null ? 'Reminder added.' : 'Reminder updated.',
          ),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save reminder. Please try again.'),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Filter panel
// ---------------------------------------------------------------------------

class _RemindersFilters extends StatelessWidget {
  const _RemindersFilters({
    required this.selectedPriority,
    required this.selectedDone,
    required this.onPrioritySelected,
    required this.onDoneSelected,
    required this.onSearchChanged,
    required this.isWide,
  });

  final String? selectedPriority;
  final bool? selectedDone;
  final ValueChanged<String?> onPrioritySelected;
  final ValueChanged<bool?> onDoneSelected;
  final ValueChanged<String> onSearchChanged;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final priorityChips = [
      FilterChip(
        label: const Text('All'),
        selected: selectedPriority == null,
        onSelected: (_) => onPrioritySelected(null),
      ),
      ...kReminderPriorities.map((entry) {
        final (code, label) = entry;
        return FilterChip(
          label: Text(label),
          selected: selectedPriority == code,
          onSelected: (_) =>
              onPrioritySelected(selectedPriority == code ? null : code),
        );
      }),
    ];

    final doneChips = [
      FilterChip(
        label: const Text('All'),
        selected: selectedDone == null,
        onSelected: (_) => onDoneSelected(null),
      ),
      FilterChip(
        label: const Text('Pending'),
        selected: selectedDone == false,
        onSelected: (_) => onDoneSelected(selectedDone == false ? null : false),
      ),
      FilterChip(
        label: const Text('Done'),
        selected: selectedDone == true,
        onSelected: (_) => onDoneSelected(selectedDone == true ? null : true),
      ),
    ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            labelText: 'Search reminders',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Priority', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (isWide)
          Wrap(spacing: 8, runSpacing: 8, children: priorityChips)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: priorityChips),
          ),
        const SizedBox(height: 16),
        Text('Status', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (isWide)
          Wrap(spacing: 8, runSpacing: 8, children: doneChips)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: doneChips),
          ),
      ],
    );

    if (isWide) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: content,
      );
    }
    return Padding(padding: const EdgeInsets.all(16), child: content);
  }
}

// ---------------------------------------------------------------------------
// Reminders list
// ---------------------------------------------------------------------------

class _RemindersList extends StatelessWidget {
  const _RemindersList({
    required this.items,
    required this.repository,
    required this.schemes,
    required this.sites,
    required this.isWide,
  });

  final List<ReminderModel> items;
  final RemindersRepository repository;
  final List<dynamic> schemes;
  final List<dynamic> sites;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No reminders found. Tap "Add Reminder" to create one.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final padding = EdgeInsets.fromLTRB(16, 8, 16, isWide ? 24 : 88);
    final listView = ListView.separated(
      padding: padding,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ReminderCard(
        reminder: items[index],
        onEdit: () => _showReminderForm(
          context,
          repository,
          schemes,
          sites,
          reminder: items[index],
        ),
        onDelete: () => _confirmDelete(context, repository, items[index]),
        onToggleDone: () =>
            repository.markDone(items[index].id, done: !items[index].isDone),
      ),
    );

    if (isWide) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: listView,
        ),
      );
    }
    return listView;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RemindersRepository repository,
    ReminderModel reminder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('"${reminder.title}" will be permanently removed.'),
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
    if (confirmed != true) return;

    await repository.deleteReminder(reminder.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reminder deleted.')));
    }
  }
}

// ---------------------------------------------------------------------------
// Reminder card
// ---------------------------------------------------------------------------

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleDone,
  });

  final ReminderModel reminder;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context) {
    final overdue = reminder.isOverdue;
    final done = reminder.isDone;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(value: done, onChanged: (_) => onToggleDone()),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    reminder.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? Colors.grey : null,
                    ),
                  ),
                ),
                _PriorityBadge(priority: reminder.priority),
                PopupMenuButton<_ReminderAction>(
                  onSelected: (action) => switch (action) {
                    _ReminderAction.edit => onEdit(),
                    _ReminderAction.delete => onDelete(),
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _ReminderAction.edit,
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: _ReminderAction.delete,
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            if (reminder.description != null &&
                reminder.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Text(
                  reminder.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (reminder.dueAt != null)
                    _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      label: _formatDate(reminder.dueAt!),
                      color: overdue ? Colors.red : null,
                    ),
                  if (reminder.schemeName != null)
                    _InfoChip(
                      icon: Icons.assignment_outlined,
                      label: reminder.schemeName!,
                    ),
                  if (reminder.siteName != null)
                    _InfoChip(
                      icon: Icons.location_on_outlined,
                      label: reminder.siteName!,
                    ),
                ],
              ),
            ),
            if (reminder.remarks != null && reminder.remarks!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Text(
                  reminder.remarks!,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: effectiveColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: effectiveColor),
        ),
      ],
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      'high' => ('High', Colors.red),
      'low' => ('Low', Colors.green),
      _ => ('Medium', Colors.orange),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _ReminderAction { edit, delete }

// ---------------------------------------------------------------------------
// Reminder form dialog
// ---------------------------------------------------------------------------

class _ReminderInput {
  const _ReminderInput({
    required this.title,
    this.description,
    this.dueAt,
    required this.priority,
    this.schemeId,
    this.siteId,
    this.remarks,
  });

  final String title;
  final String? description;
  final DateTime? dueAt;
  final String priority;
  final String? schemeId;
  final String? siteId;
  final String? remarks;
}

class _ReminderFormDialog extends StatefulWidget {
  const _ReminderFormDialog({
    this.reminder,
    required this.schemes,
    required this.sites,
  });

  final ReminderModel? reminder;
  final List<dynamic> schemes;
  final List<dynamic> sites;

  @override
  State<_ReminderFormDialog> createState() => _ReminderFormDialogState();
}

class _ReminderFormDialogState extends State<_ReminderFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _remarksCtrl;
  late String _priority;
  DateTime? _dueAt;
  String? _schemeId;
  String? _siteId;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _remarksCtrl = TextEditingController(text: r?.remarks ?? '');
    _priority = r?.priority ?? 'medium';
    _dueAt = r?.dueAt?.toLocal();
    _schemeId = r?.schemeId;
    _siteId = r?.siteId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueAt = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ReminderInput(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        dueAt: _dueAt != null
            ? DateTime(_dueAt!.year, _dueAt!.month, _dueAt!.day)
            : null,
        priority: _priority,
        schemeId: _schemeId,
        siteId: _siteId,
        remarks: _remarksCtrl.text.trim().isEmpty
            ? null
            : _remarksCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.reminder != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Reminder' : 'Add Reminder'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: kReminderPriorities
                      .map(
                        (e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                ),
                const SizedBox(height: 12),
                // Due date picker
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due date (optional)',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _dueAt == null
                          ? 'No due date'
                          : '${_dueAt!.day.toString().padLeft(2, '0')}/'
                                '${_dueAt!.month.toString().padLeft(2, '0')}/'
                                '${_dueAt!.year}',
                    ),
                  ),
                ),
                if (_dueAt != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _dueAt = null),
                      child: const Text('Clear date'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (widget.schemes.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    initialValue: _schemeId,
                    decoration: const InputDecoration(
                      labelText: 'Linked scheme (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...widget.schemes.map(
                        (s) => DropdownMenuItem(
                          value: s.id as String,
                          child: Text(s.name as String),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _schemeId = v),
                  ),
                if (widget.schemes.isNotEmpty) const SizedBox(height: 12),
                if (widget.sites.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    initialValue: _siteId,
                    decoration: const InputDecoration(
                      labelText: 'Linked site (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...widget.sites.map(
                        (s) => DropdownMenuItem(
                          value: s.id as String,
                          child: Text(s.name as String),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _siteId = v),
                  ),
                if (widget.sites.isNotEmpty) const SizedBox(height: 12),
                TextFormField(
                  controller: _remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
