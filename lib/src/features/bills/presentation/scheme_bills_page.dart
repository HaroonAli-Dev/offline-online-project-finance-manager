import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_value_extensions.dart';

import '../../schemes/domain/scheme_model.dart';
import '../../schemes/presentation/schemes_providers.dart';
import '../data/bills_repository.dart';
import '../domain/bill_model.dart';
import '../domain/bill_totals.dart';
import 'bills_page.dart';
import 'bills_providers.dart';

/// A dedicated screen showing all bills for a single scheme,
/// plus financial totals (Total Billed / Paid / Outstanding).
///
/// Opened via the scheme card's "View Bills" popup option.
class SchemeBillsPage extends ConsumerWidget {
  const SchemeBillsPage({required this.scheme, super.key});

  final SchemeModel scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(schemeBillsProvider(scheme.id));
    final totalsAsync = ref.watch(schemeBillTotalsProvider(scheme.id));
    final allSchemes = ref.watch(schemesProvider).valueOrNull ?? const [];
    final repository = ref.read(billsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bills', style: TextStyle(fontSize: 18)),
            Text(
              '${scheme.schemeCode} — ${scheme.name}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBillForm(
          context,
          repository,
          allSchemes,
          preselectedSchemeId: scheme.id,
        ),
        icon: const Icon(Icons.add_card),
        label: const Text('Add Bill'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Totals header ---
          totalsAsync.when(
            data: (totals) => _SchemeBillsTotalsHeader(totals: totals),
            loading: () => const SizedBox(
              height: 72,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, st) => const SizedBox.shrink(),
          ),
          const Divider(height: 1),
          // --- Bills list ---
          Expanded(
            child: billsAsync.when(
              data: (bills) => bills.isEmpty
                  ? const _EmptySchemeState()
                  : _SchemeBillsList(
                      bills: bills,
                      repository: repository,
                      allSchemes: allSchemes,
                      scheme: scheme,
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Unable to load bills: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Totals header
// ---------------------------------------------------------------------------

class _SchemeBillsTotalsHeader extends StatelessWidget {
  const _SchemeBillsTotalsHeader({required this.totals});

  final BillTotals totals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Expanded(
            child: _TotalTile(
              label: 'Total Billed',
              value: 'Rs. ${totals.totalBilled.toStringAsFixed(2)}',
              color: Colors.indigo,
              icon: Icons.receipt_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TotalTile(
              label: 'Paid',
              value: 'Rs. ${totals.totalPaid.toStringAsFixed(2)}',
              color: Colors.green,
              icon: Icons.check_circle_outline,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TotalTile(
              label: 'Outstanding',
              value: 'Rs. ${totals.outstanding.toStringAsFixed(2)}',
              color: totals.outstanding > 0 ? Colors.orange : Colors.grey,
              icon: Icons.pending_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bills list for the scheme
// ---------------------------------------------------------------------------

class _SchemeBillsList extends StatelessWidget {
  const _SchemeBillsList({
    required this.bills,
    required this.repository,
    required this.allSchemes,
    required this.scheme,
  });

  final List<BillModel> bills;
  final BillsRepository repository;
  final List<dynamic> allSchemes;
  final SchemeModel scheme;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: bills.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final bill = bills[index];
        return _SchemeBillTile(
          bill: bill,
          onEdit: () => showBillForm(
            context,
            repository,
            allSchemes,
            bill: bill,
            preselectedSchemeId: scheme.id,
          ),
          onDelete: () => _confirmDelete(context, repository, bill),
        );
      },
    );
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
        content: Text('${bill.billTypeDisplay} will be removed.'),
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

class _SchemeBillTile extends StatelessWidget {
  const _SchemeBillTile({
    required this.bill,
    required this.onEdit,
    required this.onDelete,
  });

  final BillModel bill;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (bill.status) {
      'submitted' => Colors.blue,
      'approved' => Colors.indigo,
      'paid' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.grey,
    };

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(Icons.receipt_outlined, color: statusColor, size: 20),
        ),
        title: Text(
          bill.billTypeDisplay,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${bill.billDate.day.toString().padLeft(2, '0')}/'
          '${bill.billDate.month.toString().padLeft(2, '0')}/'
          '${bill.billDate.year}'
          '${bill.billNumber != null ? '  •  ${bill.billNumber}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  bill.formattedAmount,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bill.statusDisplay,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            PopupMenuButton<_TileAction>(
              onSelected: (action) => switch (action) {
                _TileAction.edit => onEdit(),
                _TileAction.delete => onDelete(),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: _TileAction.edit, child: Text('Edit')),
                PopupMenuItem(value: _TileAction.delete, child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptySchemeState extends StatelessWidget {
  const _EmptySchemeState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No bills yet for this scheme.\nTap "Add Bill" to record the first billing stage.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

enum _TileAction { edit, delete }
