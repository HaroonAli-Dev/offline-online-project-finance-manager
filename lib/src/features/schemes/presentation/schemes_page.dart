import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_value_extensions.dart';

import '../../../core/widgets/hint_banner.dart';
import '../../bills/presentation/scheme_bills_page.dart';
import '../../documents/presentation/scheme_attachments_page.dart';
import '../../people/presentation/people_providers.dart';
import '../../progress/presentation/scheme_progress_page.dart';
import '../../sites/presentation/sites_providers.dart';
import '../data/schemes_repository.dart';
import '../domain/scheme_model.dart';
import 'scheme_form_dialog.dart';
import 'schemes_providers.dart';

class SchemesPage extends ConsumerWidget {
  const SchemesPage({super.key});

  static const _wideLayoutBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemes = ref.watch(schemesProvider);
    final sites = ref.watch(sitesProvider).valueOrNull ?? const [];
    final people = ref.watch(peopleProvider).valueOrNull ?? const [];
    final selectedStatus = ref.watch(schemesStatusFilterProvider);
    final repository = ref.read(schemesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schemes & Projects'),
        actions: const [PageHelpIconButton(pageKey: 'schemes')],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSchemeForm(context, repository, sites, people),
        icon: const Icon(Icons.assignment_add),
        label: const Text('Add scheme'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
          final filters = _SchemesFilters(
            selectedStatus: selectedStatus,
            onStatusSelected: (status) =>
                ref.read(schemesStatusFilterProvider.notifier).state = status,
            onSearchChanged: (value) =>
                ref.read(schemesSearchProvider.notifier).state = value,
            isWide: isWide,
          );
          final list = schemes.when(
            data: (items) => _SchemesList(
              items: items,
              repository: repository,
              sites: sites,
              people: people,
              isWide: isWide,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Unable to load schemes: $error')),
          );

          const hint = HintBanner(
            pageKey: 'schemes',
            icon: Icons.assignment_outlined,
            hints: [
              'A Scheme is a project or contract. You need at least one Site and one Person (Engineer) added first.',
              'Give each scheme a unique code (e.g. SCH-001) and a full name.',
              'Set a Budget so you can track how much is allocated to the project.',
              'Update the Progress % as work advances — the progress bar updates automatically.',
              'The colored badge on each card shows current status (e.g. green = Completed).',
              'Tap the three-dot menu (...) on a card to Edit, View Bills, or Delete a scheme.',
              'Use "View Bills" to see all billing stages (Initial, First, Second … Final) for that scheme.',
            ],
          );

          if (isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                hint,
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 280, child: filters),
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
}

Future<void> showSchemeForm(
  BuildContext context,
  SchemesRepository repository,
  List<dynamic> sites,
  List<dynamic> people, {
  SchemeModel? scheme,
}) async {
  final input = await showDialog<SchemeInput>(
    context: context,
    builder: (_) => SchemeFormDialog(
      scheme: scheme,
      sites: sites.cast(),
      people: people.cast(),
    ),
  );
  if (input == null || !context.mounted) {
    return;
  }

  try {
    if (scheme == null) {
      await repository.createScheme(
        schemeCode: input.schemeCode,
        name: input.name,
        siteId: input.siteId,
        budget: input.budget,
        engineerId: input.engineerId,
        startDate: input.startDate,
        endDate: input.endDate,
        status: input.status,
        progressPercentage: input.progressPercentage,
        incompleteReason: input.incompleteReason,
        result: input.result,
        description: input.description,
      );
    } else {
      await repository.updateScheme(
        id: scheme.id,
        schemeCode: input.schemeCode,
        name: input.name,
        siteId: input.siteId,
        budget: input.budget,
        engineerId: input.engineerId,
        startDate: input.startDate,
        endDate: input.endDate,
        status: input.status,
        progressPercentage: input.progressPercentage,
        incompleteReason: input.incompleteReason,
        result: input.result,
        description: input.description,
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(scheme == null ? 'Scheme added.' : 'Scheme updated.'),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save scheme. Please try again.'),
        ),
      );
    }
  }
}

class _SchemesFilters extends StatelessWidget {
  const _SchemesFilters({
    required this.selectedStatus,
    required this.onStatusSelected,
    required this.onSearchChanged,
    required this.isWide,
  });

  final String? selectedStatus;
  final ValueChanged<String?> onStatusSelected;
  final ValueChanged<String> onSearchChanged;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final statusChips = [
      FilterChip(
        label: const Text('All statuses'),
        selected: selectedStatus == null,
        onSelected: (_) => onStatusSelected(null),
      ),
      FilterChip(
        label: const Text('Initial'),
        selected: selectedStatus == 'initial',
        onSelected: (_) =>
            onStatusSelected(selectedStatus == 'initial' ? null : 'initial'),
      ),
      FilterChip(
        label: const Text('Working'),
        selected: selectedStatus == 'working',
        onSelected: (_) =>
            onStatusSelected(selectedStatus == 'working' ? null : 'working'),
      ),
      FilterChip(
        label: const Text('In Progress'),
        selected: selectedStatus == 'in_progress',
        onSelected: (_) => onStatusSelected(
          selectedStatus == 'in_progress' ? null : 'in_progress',
        ),
      ),
      FilterChip(
        label: const Text('Completed'),
        selected: selectedStatus == 'completed',
        onSelected: (_) => onStatusSelected(
          selectedStatus == 'completed' ? null : 'completed',
        ),
      ),
      FilterChip(
        label: const Text('Incomplete'),
        selected: selectedStatus == 'incomplete',
        onSelected: (_) => onStatusSelected(
          selectedStatus == 'incomplete' ? null : 'incomplete',
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Search schemes',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Filter by status',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (isWide)
            Wrap(spacing: 8, runSpacing: 8, children: statusChips)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: statusChips),
            ),
        ],
      ),
    );
  }
}

class _SchemesList extends StatelessWidget {
  const _SchemesList({
    required this.items,
    required this.repository,
    required this.sites,
    required this.people,
    required this.isWide,
  });

  final List<SchemeModel> items;
  final SchemesRepository repository;
  final List<dynamic> sites;
  final List<dynamic> people;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptySchemesState();
    }

    final padding = EdgeInsets.fromLTRB(16, 0, 16, isWide ? 24 : 88);
    final listView = ListView.separated(
      padding: padding,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _SchemeCard(
        scheme: items[index],
        onEdit: () => showSchemeForm(
          context,
          repository,
          sites,
          people,
          scheme: items[index],
        ),
        onDelete: () => _confirmDelete(context, repository, items[index]),
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
    SchemesRepository repository,
    SchemeModel scheme,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete scheme?'),
        content: Text(
          '${scheme.name} (${scheme.schemeCode}) will be removed from active records.',
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
    if (confirmed != true) {
      return;
    }

    await repository.deleteScheme(scheme.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Scheme deleted.')));
    }
  }
}

class _SchemeCard extends StatelessWidget {
  const _SchemeCard({
    required this.scheme,
    required this.onEdit,
    required this.onDelete,
  });

  final SchemeModel scheme;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(scheme.schemeCode),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scheme.name,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _SchemeStatusBadge(status: scheme.status),
                PopupMenuButton<_SchemeAction>(
                  onSelected: (action) => switch (action) {
                    _SchemeAction.viewBills => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SchemeBillsPage(scheme: scheme),
                      ),
                    ),
                    _SchemeAction.viewProgress => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SchemeProgressPage(scheme: scheme),
                      ),
                    ),
                    _SchemeAction.viewAttachments => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SchemeAttachmentsPage(scheme: scheme),
                      ),
                    ),
                    _SchemeAction.edit => onEdit(),
                    _SchemeAction.delete => onDelete(),
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _SchemeAction.viewBills,
                      child: Text('View Bills'),
                    ),
                    PopupMenuItem(
                      value: _SchemeAction.viewProgress,
                      child: Text('View Progress'),
                    ),
                    PopupMenuItem(
                      value: _SchemeAction.viewAttachments,
                      child: Text('View Attachments'),
                    ),
                    PopupMenuItem(
                      value: _SchemeAction.edit,
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: _SchemeAction.delete,
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (scheme.siteName != null) ...[
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text(scheme.siteName!),
                  const SizedBox(width: 16),
                ],
                if (scheme.engineerName != null) ...[
                  const Icon(Icons.engineering_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text(scheme.engineerName!),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget: ${scheme.formattedBudget}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${scheme.progressPercentage.round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: scheme.progressPercentage / 100.0,
                minHeight: 6,
              ),
            ),
            if (scheme.description != null &&
                scheme.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                scheme.description!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SchemeStatusBadge extends StatelessWidget {
  const _SchemeStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'working' => ('Working', Colors.indigo),
      'in_progress' => ('In Progress', Colors.blue),
      'completed' => ('Completed', Colors.green),
      'incomplete' => ('Incomplete', Colors.red),
      _ => ('Initial', Colors.grey),
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

class _EmptySchemesState extends StatelessWidget {
  const _EmptySchemesState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No schemes found. Create a scheme / project to track budget, engineer, and progress.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

enum _SchemeAction { viewBills, viewProgress, viewAttachments, edit, delete }
