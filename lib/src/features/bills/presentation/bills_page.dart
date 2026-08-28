import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_value_extensions.dart';

import '../../../core/widgets/hint_banner.dart';
import '../../documents/presentation/entity_attachments_page.dart';
import '../../documents/presentation/attachments_panel.dart';
import '../../schemes/presentation/schemes_providers.dart';
import '../data/bills_repository.dart';
import '../domain/bill_model.dart';
import 'bill_form_dialog.dart';
import 'bills_providers.dart';

class BillsPage extends ConsumerWidget {
  const BillsPage({super.key});

  static const _wideLayoutBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(billsProvider);
    final schemes = ref.watch(schemesProvider).valueOrNull ?? const [];
    final selectedType = ref.watch(billsTypeFilterProvider);
    final selectedStatus = ref.watch(billsStatusFilterProvider);
    final repository = ref.read(billsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        actions: const [PageHelpIconButton(pageKey: 'bills')],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBillForm(context, repository, schemes),
        icon: const Icon(Icons.add_card),
        label: const Text('Add Bill'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;

          final filters = _BillsFilters(
            selectedType: selectedType,
            selectedStatus: selectedStatus,
            onTypeSelected: (type) =>
                ref.read(billsTypeFilterProvider.notifier).state = type,
            onStatusSelected: (status) =>
                ref.read(billsStatusFilterProvider.notifier).state = status,
            onSearchChanged: (value) =>
                ref.read(billsSearchProvider.notifier).state = value,
            isWide: isWide,
          );

          final list = bills.when(
            data: (items) => _BillsList(
              items: items,
              repository: repository,
              schemes: schemes,
              isWide: isWide,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Unable to load bills: $error')),
          );

          const hint = HintBanner(
            pageKey: 'bills',
            icon: Icons.receipt_outlined,
            hints: [
              'Bills track construction billing stages for a Scheme.',
              'Stages include Initial, First, Second, Third, Fourth, Final, or Other.',
              'Tap "Add Bill" (bottom-right) to create a bill for a scheme.',
              'Each bill has a type, date, amount, and status (Draft → Submitted → Approved → Paid).',
              'To view all bills for a single scheme, open the Schemes screen and tap "View Bills".',
              'The status "Paid" contributes to the Paid total; all other statuses add to Outstanding.',
              'Use the filter chips to view bills by type or status.',
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

// ---------------------------------------------------------------------------
// Show bill form helper
// ---------------------------------------------------------------------------

Future<void> showBillForm(
  BuildContext context,
  BillsRepository repository,
  List<dynamic> schemes, {
  BillModel? bill,
  String? preselectedSchemeId,
}) async {
  final input = await showDialog<BillInput>(
    context: context,
    builder: (_) => BillFormDialog(
      bill: bill,
      schemes: schemes.cast(),
      preselectedSchemeId: preselectedSchemeId,
    ),
  );
  if (input == null || !context.mounted) return;

  try {
    if (bill == null) {
      final createdBillId = await repository.createBill(
        schemeId: input.schemeId,
        billType: input.billType,
        billNumber: input.billNumber,
        billDate: input.billDate,
        amount: input.amount,
        status: input.status,
        remarks: input.remarks,
      );
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => _BillAttachmentsDialog(billId: createdBillId),
        );
      }
    } else {
      await repository.updateBill(
        id: bill.id,
        schemeId: input.schemeId,
        billType: input.billType,
        billNumber: input.billNumber,
        billDate: input.billDate,
        amount: input.amount,
        status: input.status,
        remarks: input.remarks,
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bill == null ? 'Bill added.' : 'Bill updated.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save bill. Please try again.')),
      );
    }
  }
}

/// The second state of Add Bill: the bill now has a real local UUID, so the
/// shared offline-first attachment pipeline can safely be used.
class _BillAttachmentsDialog extends StatelessWidget {
  const _BillAttachmentsDialog({required this.billId});

  final String billId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Photos/Documents'),
      scrollable: true,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AttachmentsPanel(entityType: 'bill', entityId: billId),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filter panel
// ---------------------------------------------------------------------------

class _BillsFilters extends StatelessWidget {
  const _BillsFilters({
    required this.selectedType,
    required this.selectedStatus,
    required this.onTypeSelected,
    required this.onStatusSelected,
    required this.onSearchChanged,
    required this.isWide,
  });

  final String? selectedType;
  final String? selectedStatus;
  final ValueChanged<String?> onTypeSelected;
  final ValueChanged<String?> onStatusSelected;
  final ValueChanged<String> onSearchChanged;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final typeChips = [
      FilterChip(
        label: const Text('All types'),
        selected: selectedType == null,
        onSelected: (_) => onTypeSelected(null),
      ),
      ...kBillTypes.map((entry) {
        final (code, label) = entry;
        return FilterChip(
          label: Text(label),
          selected: selectedType == code,
          onSelected: (_) => onTypeSelected(selectedType == code ? null : code),
        );
      }),
    ];

    final statusChips = [
      FilterChip(
        label: const Text('All statuses'),
        selected: selectedStatus == null,
        onSelected: (_) => onStatusSelected(null),
      ),
      ...kBillStatuses.map((entry) {
        final (code, label) = entry;
        return FilterChip(
          label: Text(label),
          selected: selectedStatus == code,
          onSelected: (_) =>
              onStatusSelected(selectedStatus == code ? null : code),
        );
      }),
    ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            labelText: 'Search bills',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Bill type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: typeChips,
        ),
        const SizedBox(height: 16),
        Text('Status', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: statusChips,
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
// Bills list
// ---------------------------------------------------------------------------

class _BillsList extends StatelessWidget {
  const _BillsList({
    required this.items,
    required this.repository,
    required this.schemes,
    required this.isWide,
  });

  final List<BillModel> items;
  final BillsRepository repository;
  final List<dynamic> schemes;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyBillsState();
    }

    final padding = EdgeInsets.fromLTRB(16, 0, 16, isWide ? 24 : 88);
    final listView = ListView.separated(
      padding: padding,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _BillCard(
        bill: items[index],
        onEdit: () =>
            showBillForm(context, repository, schemes, bill: items[index]),
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
    BillsRepository repository,
    BillModel bill,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete bill?'),
        content: Text(
          '${bill.billTypeDisplay} for ${bill.schemeName} will be removed.',
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
    if (confirmed != true) return;

    await repository.deleteBill(bill.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bill deleted.')));
    }
  }
}

// ---------------------------------------------------------------------------
// Bill card
// ---------------------------------------------------------------------------

class _BillCard extends StatelessWidget {
  const _BillCard({
    required this.bill,
    required this.onEdit,
    required this.onDelete,
  });

  final BillModel bill;
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
                _BillTypeBadge(billType: bill.billType),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bill.schemeName,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _BillStatusBadge(status: bill.status),
                PopupMenuButton<_BillAction>(
                  onSelected: (action) => switch (action) {
                    _BillAction.edit => onEdit(),
                    _BillAction.delete => onDelete(),
                    _BillAction.attachments => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EntityAttachmentsPage(
                          entityType: 'bill',
                          entityId: bill.id,
                          title: bill.schemeName,
                        ),
                      ),
                    ),
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _BillAction.edit, child: Text('Edit')),
                    PopupMenuItem(
                      value: _BillAction.delete,
                      child: Text('Delete'),
                    ),
                    PopupMenuItem(
                      value: _BillAction.attachments,
                      child: Text('Attachments'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${bill.billDate.day.toString().padLeft(2, '0')}/'
                  '${bill.billDate.month.toString().padLeft(2, '0')}/'
                  '${bill.billDate.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (bill.siteName != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.location_on_outlined, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    bill.siteName!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (bill.billNumber != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.tag, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    bill.billNumber!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  bill.formattedAmount,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (bill.remarks != null && bill.remarks!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                bill.remarks!,
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

// ---------------------------------------------------------------------------
// Status and type badges
// ---------------------------------------------------------------------------

class _BillStatusBadge extends StatelessWidget {
  const _BillStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'submitted' => ('Submitted', Colors.blue),
      'approved' => ('Approved', Colors.indigo),
      'paid' => ('Paid', Colors.green),
      'rejected' => ('Rejected', Colors.red),
      _ => ('Draft', Colors.grey),
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

class _BillTypeBadge extends StatelessWidget {
  const _BillTypeBadge({required this.billType});

  final String billType;

  @override
  Widget build(BuildContext context) {
    final label = switch (billType) {
      'initial' => 'Initial',
      'first' => '1st',
      'second' => '2nd',
      'third' => '3rd',
      'fourth' => '4th',
      'final' => 'Final',
      _ => 'Other',
    };

    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyBillsState extends StatelessWidget {
  const _EmptyBillsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No bills found. Tap "Add Bill" to create the first billing record for a scheme.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

enum _BillAction { edit, delete, attachments }
