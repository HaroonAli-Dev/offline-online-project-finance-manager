import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/hint_banner.dart';
import '../../documents/presentation/entity_attachments_page.dart';
import '../data/sites_repository.dart';
import '../domain/site_model.dart';
import 'site_form_dialog.dart';
import 'sites_providers.dart';

class SitesPage extends ConsumerWidget {
  const SitesPage({super.key});

  static const _wideLayoutBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(sitesProvider);
    final selectedStatus = ref.watch(sitesStatusFilterProvider);
    final repository = ref.read(sitesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sites'),
        actions: const [PageHelpIconButton(pageKey: 'sites')],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSiteForm(context, repository),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add site'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
          final filters = _SitesFilters(
            selectedStatus: selectedStatus,
            onStatusSelected: (status) =>
                ref.read(sitesStatusFilterProvider.notifier).state = status,
            onSearchChanged: (value) =>
                ref.read(sitesSearchProvider.notifier).state = value,
            isWide: isWide,
          );
          final list = sites.when(
            data: (items) => _SitesList(
              items: items,
              repository: repository,
              isWide: isWide,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Unable to load sites: $error')),
          );

          const hint = HintBanner(
            pageKey: 'sites',
            icon: Icons.location_city_outlined,
            hints: [
              'Add a site first — Schemes and Vehicles need a site to link to.',
              'Tap "Add site" (bottom-right) to register a construction location or road segment.',
              'GPS Latitude/Longitude is optional. Find it on Google Maps by right-clicking.',
              'Set the Status: Planned → Active → On Hold → Completed as work progresses.',
              'Use the filter chips to quickly see only Active or Completed sites.',
              'Tap the three-dot menu (...) on a card to Edit or Delete a site.',
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

Future<void> showSiteForm(
  BuildContext context,
  SitesRepository repository, {
  SiteModel? site,
}) async {
  final input = await showDialog<SiteInput>(
    context: context,
    builder: (_) => SiteFormDialog(site: site),
  );
  if (input == null || !context.mounted) {
    return;
  }

  try {
    if (site == null) {
      await repository.createSite(
        name: input.name,
        roadInfo: input.roadInfo,
        latitude: input.latitude,
        longitude: input.longitude,
        status: input.status,
        notes: input.notes,
      );
    } else {
      await repository.updateSite(
        id: site.id,
        name: input.name,
        roadInfo: input.roadInfo,
        latitude: input.latitude,
        longitude: input.longitude,
        status: input.status,
        notes: input.notes,
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(site == null ? 'Site added.' : 'Site updated.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save site. Please try again.')),
      );
    }
  }
}

class _SitesFilters extends StatelessWidget {
  const _SitesFilters({
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
        label: const Text('Active'),
        selected: selectedStatus == 'active',
        onSelected: (_) =>
            onStatusSelected(selectedStatus == 'active' ? null : 'active'),
      ),
      FilterChip(
        label: const Text('Completed'),
        selected: selectedStatus == 'completed',
        onSelected: (_) => onStatusSelected(
          selectedStatus == 'completed' ? null : 'completed',
        ),
      ),
      FilterChip(
        label: const Text('On Hold'),
        selected: selectedStatus == 'on_hold',
        onSelected: (_) =>
            onStatusSelected(selectedStatus == 'on_hold' ? null : 'on_hold'),
      ),
      FilterChip(
        label: const Text('Planned'),
        selected: selectedStatus == 'planned',
        onSelected: (_) =>
            onStatusSelected(selectedStatus == 'planned' ? null : 'planned'),
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
              labelText: 'Search sites',
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
          Wrap(spacing: 8, runSpacing: 8, children: statusChips),
        ],
      ),
    );
  }
}

class _SitesList extends StatelessWidget {
  const _SitesList({
    required this.items,
    required this.repository,
    required this.isWide,
  });

  final List<SiteModel> items;
  final SitesRepository repository;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptySitesState();
    }

    final padding = EdgeInsets.fromLTRB(16, 0, 16, isWide ? 24 : 88);
    final listView = ListView.separated(
      padding: padding,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _SiteCard(
        site: items[index],
        onEdit: () => showSiteForm(context, repository, site: items[index]),
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
    SitesRepository repository,
    SiteModel site,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete site?'),
        content: Text('${site.name} will be removed from active records.'),
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

    await repository.deleteSite(site.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Site deleted.')));
    }
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.site,
    required this.onEdit,
    required this.onDelete,
  });

  final SiteModel site;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitleLines = <Widget>[
      if (site.roadInfo != null && site.roadInfo!.isNotEmpty)
        Text('Road: ${site.roadInfo}'),
      if (site.latitude != null && site.longitude != null)
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 14),
            const SizedBox(width: 4),
            Text(site.coordinatesDisplay),
          ],
        ),
    ];

    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.location_city_outlined)),
        title: Row(
          children: [
            Expanded(child: Text(site.name)),
            _StatusBadge(status: site.status),
          ],
        ),
        subtitle: subtitleLines.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: subtitleLines,
              ),
        isThreeLine: subtitleLines.length > 1,
        trailing: PopupMenuButton<_SiteAction>(
          onSelected: (action) => switch (action) {
            _SiteAction.edit => onEdit(),
            _SiteAction.delete => onDelete(),
            _SiteAction.attachments => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EntityAttachmentsPage(
                  entityType: 'site',
                  entityId: site.id,
                  title: site.name,
                ),
              ),
            ),
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: _SiteAction.edit, child: Text('Edit')),
            const PopupMenuItem(
              value: _SiteAction.delete,
              child: Text('Delete'),
            ),
            const PopupMenuItem(
              value: _SiteAction.attachments,
              child: Text('Attachments'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'completed' => ('Completed', Colors.green),
      'on_hold' => ('On Hold', Colors.orange),
      'planned' => ('Planned', Colors.blue),
      _ => ('Active', Colors.teal),
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

class _EmptySitesState extends StatelessWidget {
  const _EmptySitesState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No sites found. Add a construction site or road segment to manage.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

enum _SiteAction { edit, delete, attachments }
