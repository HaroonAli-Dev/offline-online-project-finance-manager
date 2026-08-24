import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_value_extensions.dart';

import '../../../core/widgets/hint_banner.dart';
import '../../people/presentation/people_providers.dart';
import '../../schemes/presentation/schemes_providers.dart';
import '../../sites/presentation/sites_providers.dart';
import '../data/transactions_repository.dart';
import '../domain/transaction_model.dart';
import 'transaction_form_dialog.dart';
import 'transactions_providers.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  static const _wideLayoutBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final metrics = ref.watch(transactionsSummaryProvider);
    final people = ref.watch(peopleProvider).valueOrNull ?? const [];
    final schemes = ref.watch(schemesProvider).valueOrNull ?? const [];
    final sites = ref.watch(sitesProvider).valueOrNull ?? const [];
    final selectedType = ref.watch(transactionsTypeFilterProvider);
    final repository = ref.read(transactionsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Transactions'),
        actions: const [PageHelpIconButton(pageKey: 'transactions')],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showTransactionForm(context, repository, people, schemes, sites),
        icon: const Icon(Icons.add_card),
        label: const Text('Add Transaction'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
          final headerMetrics = _SummaryMetricsHeader(metrics: metrics);
          final filters = _TransactionsFilters(
            selectedType: selectedType,
            onTypeSelected: (type) =>
                ref.read(transactionsTypeFilterProvider.notifier).state = type,
            onSearchChanged: (value) =>
                ref.read(transactionsSearchProvider.notifier).state = value,
            isWide: isWide,
          );
          final list = transactions.when(
            data: (items) => _TransactionsList(
              items: items,
              repository: repository,
              people: people,
              schemes: schemes,
              sites: sites,
              isWide: isWide,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Unable to load transactions: $error')),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    headerMetrics,
                    const Divider(height: 1),
                    const HintBanner(
                      pageKey: 'transactions',
                      icon: Icons.account_balance_wallet_outlined,
                      hints: [
                        'The summary bar at the top shows Total Received (green), Total Paid (red), and Net Balance (blue/orange).',
                        'Tap "Add Transaction" (bottom-right) to record money in or money out.',
                        'Choose "Money Received" when someone pays you; choose "Money Paid" when you pay someone.',
                        'Always enter a unique Transaction Code (e.g. TXN-001) for easy reference.',
                        'Link each transaction to a Scheme or Site to track project-level finances.',
                        'Green arrow (down) on a card = money received. Red arrow (up) = money paid.',
                        'Use the filter chips to view only "Money Received" or "Money Paid" entries.',
                      ],
                    ),
                    if (!isWide) filters,
                  ],
                ),
              ),
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 280, child: filters),
                          const VerticalDivider(width: 1),
                          Expanded(child: list),
                        ],
                      )
                    : list,
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> showTransactionForm(
  BuildContext context,
  TransactionsRepository repository,
  List<dynamic> people,
  List<dynamic> schemes,
  List<dynamic> sites, {
  TransactionModel? transaction,
}) async {
  final input = await showDialog<TransactionInput>(
    context: context,
    builder: (_) => TransactionFormDialog(
      transaction: transaction,
      people: people.cast(),
      schemes: schemes.cast(),
      sites: sites.cast(),
    ),
  );
  if (input == null || !context.mounted) {
    return;
  }

  try {
    if (transaction == null) {
      await repository.createTransaction(
        transactionCode: input.transactionCode,
        transactionDate: input.transactionDate,
        type: input.type,
        personId: input.personId,
        amount: input.amount,
        quantity: input.quantity,
        purpose: input.purpose,
        paymentMethod: input.paymentMethod,
        referenceNumber: input.referenceNumber,
        remarks: input.remarks,
        schemeId: input.schemeId,
        siteId: input.siteId,
      );
    } else {
      await repository.updateTransaction(
        id: transaction.id,
        transactionCode: input.transactionCode,
        transactionDate: input.transactionDate,
        type: input.type,
        personId: input.personId,
        amount: input.amount,
        quantity: input.quantity,
        purpose: input.purpose,
        paymentMethod: input.paymentMethod,
        referenceNumber: input.referenceNumber,
        remarks: input.remarks,
        schemeId: input.schemeId,
        siteId: input.siteId,
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            transaction == null ? 'Transaction added.' : 'Transaction updated.',
          ),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save transaction. Please try again.'),
        ),
      );
    }
  }
}

class _SummaryMetricsHeader extends StatelessWidget {
  const _SummaryMetricsHeader({required this.metrics});

  final TransactionSummaryMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Expanded(
            child: _MetricTile(
              label: 'Total Received',
              value: 'Rs. ${metrics.totalReceived.toStringAsFixed(2)}',
              color: Colors.green,
              icon: Icons.arrow_downward,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MetricTile(
              label: 'Total Paid',
              value: 'Rs. ${metrics.totalPaid.toStringAsFixed(2)}',
              color: Colors.red,
              icon: Icons.arrow_upward,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MetricTile(
              label: 'Net Balance',
              value: 'Rs. ${metrics.balance.toStringAsFixed(2)}',
              color: metrics.balance >= 0 ? Colors.blue : Colors.orange,
              icon: Icons.account_balance_wallet,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
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
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionsFilters extends StatelessWidget {
  const _TransactionsFilters({
    required this.selectedType,
    required this.onTypeSelected,
    required this.onSearchChanged,
    required this.isWide,
  });

  final String? selectedType;
  final ValueChanged<String?> onTypeSelected;
  final ValueChanged<String> onSearchChanged;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final typeChips = [
      FilterChip(
        label: const Text('All transactions'),
        selected: selectedType == null,
        onSelected: (_) => onTypeSelected(null),
      ),
      FilterChip(
        label: const Text('Money Received'),
        selected: selectedType == 'received',
        onSelected: (_) =>
            onTypeSelected(selectedType == 'received' ? null : 'received'),
      ),
      FilterChip(
        label: const Text('Money Paid'),
        selected: selectedType == 'paid',
        onSelected: (_) =>
            onTypeSelected(selectedType == 'paid' ? null : 'paid'),
      ),
    ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            labelText: 'Search transactions',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Filter by type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: typeChips,
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

class _TransactionsList extends StatelessWidget {
  const _TransactionsList({
    required this.items,
    required this.repository,
    required this.people,
    required this.schemes,
    required this.sites,
    required this.isWide,
  });

  final List<TransactionModel> items;
  final TransactionsRepository repository;
  final List<dynamic> people;
  final List<dynamic> schemes;
  final List<dynamic> sites;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyTransactionsState();
    }

    final padding = EdgeInsets.fromLTRB(16, 0, 16, isWide ? 24 : 88);
    final listView = ListView.separated(
      padding: padding,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _TransactionCard(
        transaction: items[index],
        onEdit: () => showTransactionForm(
          context,
          repository,
          people,
          schemes,
          sites,
          transaction: items[index],
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
    TransactionsRepository repository,
    TransactionModel txn,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
          '${txn.transactionCode} (${txn.purpose}) will be removed from active records.',
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

    await repository.deleteTransaction(txn.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Transaction deleted.')));
    }
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionModel transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isReceived = transaction.isReceived;
    final color = isReceived ? Colors.green : Colors.red;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            isReceived ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Row(
          children: [
            Chip(
              label: Text(transaction.transactionCode),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(transaction.purpose)),
            Text(
              transaction.formattedAmount,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(_formatDate(transaction.transactionDate)),
                const SizedBox(width: 8),
                Chip(
                  label: Text(transaction.paymentMethodDisplay),
                  visualDensity: VisualDensity.compact,
                ),
                if (transaction.referenceNumber != null) ...[
                  const SizedBox(width: 8),
                  Text('Ref: ${transaction.referenceNumber}'),
                ],
              ],
            ),
            if (transaction.personName != null ||
                transaction.schemeName != null ||
                transaction.siteName != null) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                children: [
                  if (transaction.personName != null)
                    Text('Person: ${transaction.personName}'),
                  if (transaction.schemeName != null)
                    Text('Scheme: ${transaction.schemeName}'),
                  if (transaction.siteName != null)
                    Text('Site: ${transaction.siteName}'),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<_TxnAction>(
          onSelected: (action) => switch (action) {
            _TxnAction.edit => onEdit(),
            _TxnAction.delete => onDelete(),
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: _TxnAction.edit, child: Text('Edit')),
            const PopupMenuItem(
              value: _TxnAction.delete,
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  const _EmptyTransactionsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No transactions found. Record received or paid money to track financial balances.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

enum _TxnAction { edit, delete }
