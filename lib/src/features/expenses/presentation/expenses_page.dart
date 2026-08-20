import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_value_extensions.dart';

import '../../../core/services/file_launcher_service.dart';
import '../../../core/widgets/hint_banner.dart';
import '../../people/presentation/people_providers.dart';
import '../../schemes/presentation/schemes_providers.dart';
import '../../sites/presentation/sites_providers.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_model.dart';
import 'expense_form_dialog.dart';
import 'expenses_providers.dart';

class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  static const _wideLayoutBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);
    final totalExpenses = ref.watch(totalExpensesSummaryProvider);
    final sites = ref.watch(sitesProvider).valueOrNull ?? const [];
    final schemes = ref.watch(schemesProvider).valueOrNull ?? const [];
    final people = ref.watch(peopleProvider).valueOrNull ?? const [];
    final selectedCategory = ref.watch(expensesCategoryFilterProvider);
    final repository = ref.read(expensesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: const [PageHelpIconButton(pageKey: 'expenses')],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showExpenseForm(context, repository, sites, schemes, people),
        icon: const Icon(Icons.receipt_long),
        label: const Text('Add Expense'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
          final headerMetrics = _TotalExpensesHeader(total: totalExpenses);
          final filters = _ExpensesFilters(
            selectedCategory: selectedCategory,
            onCategorySelected: (cat) =>
                ref.read(expensesCategoryFilterProvider.notifier).state = cat,
            onSearchChanged: (value) =>
                ref.read(expensesSearchProvider.notifier).state = value,
            isWide: isWide,
          );
          final list = expenses.when(
            data: (items) => _ExpensesList(
              items: items,
              repository: repository,
              sites: sites,
              schemes: schemes,
              people: people,
              isWide: isWide,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Unable to load expenses: $error')),
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
                      pageKey: 'expenses',
                      icon: Icons.receipt_long_outlined,
                      hints: [
                        'Expenses are day-to-day costs. The total bar at the top shows all recorded expenses.',
                        'Tap "Add Expense" (bottom-right) to record a new cost.',
                        'Choose the correct Category (e.g. Labour, Vehicle, Material) for easy reporting.',
                        'Always enter a unique Expense Code (e.g. EXP-001) for reference.',
                        'Link each expense to a Site, Scheme, or Person to know where money was spent.',
                        'A paperclip icon on a card means a receipt/attachment is stored with that expense.',
                        'Use the category filter chips to view only one type of expense at a time.',
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

Future<void> showExpenseForm(
  BuildContext context,
  ExpensesRepository repository,
  List<dynamic> sites,
  List<dynamic> schemes,
  List<dynamic> people, {
  ExpenseModel? expense,
}) async {
  final input = await showDialog<ExpenseInput>(
    context: context,
    builder: (_) => ExpenseFormDialog(
      expense: expense,
      sites: sites.cast(),
      schemes: schemes.cast(),
      people: people.cast(),
    ),
  );
  if (input == null || !context.mounted) {
    return;
  }

  try {
    if (expense == null) {
      await repository.createExpense(
        expenseCode: input.expenseCode,
        expenseDate: input.expenseDate,
        category: input.category,
        amount: input.amount,
        purpose: input.purpose,
        siteId: input.siteId,
        schemeId: input.schemeId,
        personId: input.personId,
        remarks: input.remarks,
        attachmentPath: input.attachmentPath,
      );
    } else {
      await repository.updateExpense(
        id: expense.id,
        expenseCode: input.expenseCode,
        expenseDate: input.expenseDate,
        category: input.category,
        amount: input.amount,
        purpose: input.purpose,
        siteId: input.siteId,
        schemeId: input.schemeId,
        personId: input.personId,
        remarks: input.remarks,
        attachmentPath: input.attachmentPath,
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            expense == null ? 'Expense recorded.' : 'Expense updated.',
          ),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save expense. Please try again.'),
        ),
      );
    }
  }
}

class _TotalExpensesHeader extends StatelessWidget {
  const _TotalExpensesHeader({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Total Expenses Recorded',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          Text(
            'Rs. ${total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpensesFilters extends StatelessWidget {
  const _ExpensesFilters({
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onSearchChanged,
    required this.isWide,
  });

  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<String> onSearchChanged;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final categories = [
      ('All', null),
      ('Personal', 'personal'),
      ('Labour', 'labour'),
      ('Vehicle', 'vehicle'),
      ('Office', 'office'),
      ('Security', 'security'),
      ('Dinner', 'dinner'),
      ('Material', 'material'),
      ('Miscellaneous', 'miscellaneous'),
    ];

    final categoryChips = categories.map((cat) {
      final (label, code) = cat;
      final isSelected = selectedCategory == code;
      return FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onCategorySelected(isSelected ? null : code),
      );
    }).toList();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            labelText: 'Search expenses',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Filter by category',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (isWide)
          Wrap(spacing: 8, runSpacing: 8, children: categoryChips)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: categoryChips),
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

class _ExpensesList extends StatelessWidget {
  const _ExpensesList({
    required this.items,
    required this.repository,
    required this.sites,
    required this.schemes,
    required this.people,
    required this.isWide,
  });

  final List<ExpenseModel> items;
  final ExpensesRepository repository;
  final List<dynamic> sites;
  final List<dynamic> schemes;
  final List<dynamic> people;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyExpensesState();
    }

    final padding = EdgeInsets.fromLTRB(16, 0, 16, isWide ? 24 : 88);
    final listView = ListView.separated(
      padding: padding,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ExpenseCard(
        expense: items[index],
        onEdit: () => showExpenseForm(
          context,
          repository,
          sites,
          schemes,
          people,
          expense: items[index],
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
    ExpensesRepository repository,
    ExpenseModel expense,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          '${expense.expenseCode} (${expense.purpose}) will be removed from active records.',
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

    await repository.deleteExpense(expense.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Expense deleted.')));
    }
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseModel expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.shopping_bag_outlined)),
        title: Row(
          children: [
            Chip(
              label: Text(expense.expenseCode),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(expense.purpose)),
            Text(
              expense.formattedAmount,
              style: TextStyle(
                color: Colors.red.shade700,
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
                Text(_formatDate(expense.expenseDate)),
                const SizedBox(width: 8),
                Chip(
                  label: Text(expense.categoryDisplay),
                  visualDensity: VisualDensity.compact,
                ),
                if (expense.attachmentPath != null &&
                    expense.attachmentPath!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final path = expense.attachmentPath!;
                      FileLauncherService.openFile(path);
                    },
                    child: Tooltip(
                      message:
                          'Click to open attachment: ${expense.attachmentPath}',
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_file,
                              size: 16,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'Receipt',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (expense.siteName != null ||
                expense.schemeName != null ||
                expense.personName != null) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                children: [
                  if (expense.siteName != null)
                    Text('Site: ${expense.siteName}'),
                  if (expense.schemeName != null)
                    Text('Scheme: ${expense.schemeName}'),
                  if (expense.personName != null)
                    Text('Person: ${expense.personName}'),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<_ExpenseAction>(
          onSelected: (action) => switch (action) {
            _ExpenseAction.edit => onEdit(),
            _ExpenseAction.delete => onDelete(),
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: _ExpenseAction.edit,
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: _ExpenseAction.delete,
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

class _EmptyExpensesState extends StatelessWidget {
  const _EmptyExpensesState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No expenses found. Record personal, labour, vehicle, material, or office expenses.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

enum _ExpenseAction { edit, delete }
