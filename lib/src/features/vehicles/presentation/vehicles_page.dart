import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_value_extensions.dart';

import '../../../core/widgets/hint_banner.dart';
import '../../people/presentation/people_providers.dart';
import '../../sites/presentation/sites_providers.dart';
import '../data/vehicles_repository.dart';
import '../domain/vehicle_model.dart';
import 'vehicle_form_dialog.dart';
import 'vehicles_providers.dart';

class VehiclesPage extends ConsumerWidget {
  const VehiclesPage({super.key});

  static const _wideLayoutBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);
    final sites = ref.watch(sitesProvider).valueOrNull ?? const [];
    final people = ref.watch(peopleProvider).valueOrNull ?? const [];
    final selectedStatus = ref.watch(vehiclesStatusFilterProvider);
    final repository = ref.read(vehiclesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicles & Drivers'),
        actions: const [PageHelpIconButton(pageKey: 'vehicles')],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showVehicleForm(context, repository, sites, people),
        icon: const Icon(Icons.directions_car_outlined),
        label: const Text('Add Vehicle'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
          final filters = _VehiclesFilters(
            selectedStatus: selectedStatus,
            onStatusSelected: (status) =>
                ref.read(vehiclesStatusFilterProvider.notifier).state = status,
            onSearchChanged: (value) =>
                ref.read(vehiclesSearchProvider.notifier).state = value,
            isWide: isWide,
          );
          final list = vehicles.when(
            data: (items) => _VehiclesList(
              items: items,
              repository: repository,
              sites: sites,
              people: people,
              isWide: isWide,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Unable to load vehicles: $error')),
          );

          const hint = HintBanner(
            pageKey: 'vehicles',
            icon: Icons.directions_bus_outlined,
            hints: [
              'Tap "Add Vehicle" (bottom-right) to register a truck, dumper, excavator, or any vehicle.',
              'Assign a Driver and a Site to each vehicle so you know who is using it and where.',
              'Click anywhere on a vehicle card to expand it and see its fuel/maintenance log history.',
              'Tap the fuel pump icon (top-right of card) to add a Fuel Fill, Maintenance, or Trip log.',
              'Each log records date, cost, liters, driver, and odometer reading.',
              'To delete a log entry, tap the trash icon next to that log in the expanded view.',
              'Use the status chips (Active / Under Maintenance / Inactive) to filter vehicles.',
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

Future<void> showVehicleForm(
  BuildContext context,
  VehiclesRepository repository,
  List<dynamic> sites,
  List<dynamic> people, {
  VehicleModel? vehicle,
}) async {
  final input = await showDialog<VehicleInput>(
    context: context,
    builder: (_) => VehicleFormDialog(
      vehicle: vehicle,
      sites: sites.cast(),
      people: people.cast(),
    ),
  );
  if (input == null || !context.mounted) {
    return;
  }

  try {
    if (vehicle == null) {
      await repository.createVehicle(
        vehicleNumber: input.vehicleNumber,
        makeModel: input.makeModel,
        vehicleType: input.vehicleType,
        assignedSiteId: input.assignedSiteId,
        assignedDriverId: input.assignedDriverId,
        status: input.status,
        remarks: input.remarks,
      );
    } else {
      await repository.updateVehicle(
        id: vehicle.id,
        vehicleNumber: input.vehicleNumber,
        makeModel: input.makeModel,
        vehicleType: input.vehicleType,
        assignedSiteId: input.assignedSiteId,
        assignedDriverId: input.assignedDriverId,
        status: input.status,
        remarks: input.remarks,
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vehicle == null ? 'Vehicle added.' : 'Vehicle updated.',
          ),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save vehicle. Please try again.'),
        ),
      );
    }
  }
}

class _VehiclesFilters extends StatelessWidget {
  const _VehiclesFilters({
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
        label: const Text('Under Maintenance'),
        selected: selectedStatus == 'under_maintenance',
        onSelected: (_) => onStatusSelected(
          selectedStatus == 'under_maintenance' ? null : 'under_maintenance',
        ),
      ),
      FilterChip(
        label: const Text('Inactive'),
        selected: selectedStatus == 'inactive',
        onSelected: (_) =>
            onStatusSelected(selectedStatus == 'inactive' ? null : 'inactive'),
      ),
    ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            labelText: 'Search vehicles',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Filter by status', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: statusChips),
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

class _VehiclesList extends StatelessWidget {
  const _VehiclesList({
    required this.items,
    required this.repository,
    required this.sites,
    required this.people,
    required this.isWide,
  });

  final List<VehicleModel> items;
  final VehiclesRepository repository;
  final List<dynamic> sites;
  final List<dynamic> people;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyVehiclesState();
    }

    final padding = EdgeInsets.fromLTRB(16, 0, 16, isWide ? 24 : 88);
    final listView = ListView.separated(
      padding: padding,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _VehicleCard(
        vehicle: items[index],
        repository: repository,
        sites: sites,
        people: people,
        onEdit: () => showVehicleForm(
          context,
          repository,
          sites,
          people,
          vehicle: items[index],
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
    VehiclesRepository repository,
    VehicleModel vehicle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: Text(
          '${vehicle.vehicleNumber} (${vehicle.makeModel}) will be removed from active records.',
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

    await repository.deleteVehicle(vehicle.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vehicle deleted.')));
    }
  }
}

class _VehicleCard extends ConsumerWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.repository,
    required this.sites,
    required this.people,
    required this.onEdit,
    required this.onDelete,
  });

  final VehicleModel vehicle;
  final VehiclesRepository repository;
  final List<dynamic> sites;
  final List<dynamic> people;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(vehicleLogsFamilyProvider(vehicle.id));

    return Card(
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.directions_bus_outlined)),
        title: Row(
          children: [
            Chip(
              label: Text(vehicle.vehicleNumber),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(vehicle.makeModel)),
            _VehicleStatusBadge(status: vehicle.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 12,
            children: [
              Text('Type: ${vehicle.typeDisplay}'),
              if (vehicle.assignedDriverName != null)
                Text('Driver: ${vehicle.assignedDriverName}'),
              if (vehicle.assignedSiteName != null)
                Text('Site: ${vehicle.assignedSiteName}'),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.local_gas_station_outlined),
              tooltip: 'Add Fuel/Log',
              onPressed: () => _showAddLog(context),
            ),
            PopupMenuButton<_VehicleAction>(
              onSelected: (action) => switch (action) {
                _VehicleAction.edit => onEdit(),
                _VehicleAction.delete => onDelete(),
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _VehicleAction.edit,
                  child: Text('Edit Vehicle'),
                ),
                const PopupMenuItem(
                  value: _VehicleAction.delete,
                  child: Text('Delete Vehicle'),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Log History (Fuel / Maintenance / Trips)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Log'),
                      onPressed: () => _showAddLog(context),
                    ),
                  ],
                ),
                logsAsync.when(
                  data: (logs) {
                    if (logs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No logs recorded yet.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      );
                    }
                    return Column(
                      children: logs
                          .map(
                            (log) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(log.description),
                              subtitle: Text(
                                '${_formatDate(log.logDate)} · ${log.logTypeDisplay}'
                                '${log.quantityLiters != null ? ' · ${log.quantityLiters} L' : ''}'
                                '${log.driverName != null ? ' · ${log.driverName}' : ''}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    log.formattedAmount,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                    ),
                                    onPressed: () =>
                                        repository.deleteVehicleLog(log.id),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error loading logs: $e'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddLog(BuildContext context) async {
    final input = await showDialog<VehicleLogInput>(
      context: context,
      builder: (_) =>
          VehicleLogFormDialog(people: people.cast(), sites: sites.cast()),
    );
    if (input == null || !context.mounted) return;

    await repository.addVehicleLog(
      vehicleId: vehicle.id,
      logDate: input.logDate,
      logType: input.logType,
      amount: input.amount,
      quantityLiters: input.quantityLiters,
      driverId: input.driverId,
      siteId: input.siteId,
      description: input.description,
      odometerReading: input.odometerReading,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vehicle log added.')));
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _VehicleStatusBadge extends StatelessWidget {
  const _VehicleStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'under_maintenance' => ('Maintenance', Colors.orange),
      'inactive' => ('Inactive', Colors.grey),
      _ => ('Active', Colors.green),
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

class _EmptyVehiclesState extends StatelessWidget {
  const _EmptyVehiclesState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No vehicles registered. Add trucks, dumpers, excavators, or tractors to track fuel & maintenance.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

enum _VehicleAction { edit, delete }
