import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_value_extensions.dart';

import '../../../core/widgets/hint_banner.dart';
import '../../bills/presentation/bills_providers.dart';
import '../../expenses/presentation/expenses_page.dart';
import '../../expenses/presentation/expenses_providers.dart';
import '../../people/presentation/people_page.dart';
import '../../people/presentation/people_providers.dart';
import '../../reminders/domain/reminder_model.dart';
import '../../reminders/presentation/reminders_providers.dart';
import '../../schemes/presentation/schemes_page.dart';
import '../../schemes/presentation/schemes_providers.dart';
import '../../sites/presentation/sites_page.dart';
import '../../sites/presentation/sites_providers.dart';
import '../../transactions/presentation/transactions_page.dart';
import '../../transactions/presentation/transactions_providers.dart';
import '../widgets/backup_export_dialog.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardTransactionSummaryProvider);
    final totalExpenses = ref.watch(dashboardTotalExpensesProvider);
    final billsSummary = ref.watch(dashboardBillsSummaryProvider);
    final upcomingReminders =
        ref.watch(dashboardUpcomingRemindersProvider).valueOrNull ?? const [];
    final remindersRepo = ref.read(remindersRepositoryProvider);

    final people = ref.watch(peopleProvider).valueOrNull ?? const [];
    final sites = ref.watch(sitesProvider).valueOrNull ?? const [];
    final schemes = ref.watch(schemesProvider).valueOrNull ?? const [];
    final roles = ref.watch(rolesProvider).valueOrNull ?? const [];

    final txRepo = ref.read(transactionsRepositoryProvider);
    final expRepo = ref.read(expensesRepositoryProvider);
    final peopleRepo = ref.read(peopleRepositoryProvider);
    final sitesRepo = ref.read(sitesRepositoryProvider);
    final schemesRepo = ref.read(schemesRepositoryProvider);

    final activeSitesCount = sites.where((s) => s.status == 'active').length;
    final activeSchemesCount = schemes
        .where((s) => s.status == 'working' || s.status == 'in_progress')
        .length;
    final completedSchemesCount = schemes
        .where((s) => s.status == 'completed')
        .length;
    final incompleteSchemesCount = schemes
        .where((s) => s.status == 'incomplete')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export & Backup',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const BackupExportDialog(),
            ),
          ),
          const PageHelpIconButton(pageKey: 'dashboard'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HintBanner(
              pageKey: 'dashboard',
              icon: Icons.dashboard_outlined,
              hints: [
                'Welcome to the Dashboard! Here is a high-level overview of your finances, projects, and workforce.',
                'Use Quick Actions to quickly record a transaction, expense, person, or site.',
                'Check Scheme Progress to monitor budget allocations and completion status.',
                'Upcoming Reminders shows overdue and due-soon tasks. Tap the checkbox to mark them done.',
                'Click the Export & Backup button in the top right to download CSV reports or back up your database.',
              ],
            ),
            const SizedBox(height: 12),

            // ----------------------------------------------------------------
            // Financial Overview
            // ----------------------------------------------------------------
            const _SectionTitle('Financial Overview'),
            const SizedBox(height: 12),
            _ResponsiveCardGrid(
              cards: [
                _SummaryCard(
                  title: 'Total Received',
                  value: 'Rs. ${metrics.totalReceived.toStringAsFixed(2)}',
                  color: Colors.green,
                  icon: Icons.arrow_downward,
                ),
                _SummaryCard(
                  title: 'Total Paid',
                  value: 'Rs. ${metrics.totalPaid.toStringAsFixed(2)}',
                  color: Colors.red,
                  icon: Icons.arrow_upward,
                ),
                _SummaryCard(
                  title: 'Net Balance',
                  value: 'Rs. ${metrics.balance.toStringAsFixed(2)}',
                  color: metrics.balance >= 0 ? Colors.blue : Colors.orange,
                  icon: Icons.account_balance_wallet,
                ),
                _SummaryCard(
                  title: 'Total Expenses',
                  value: 'Rs. ${totalExpenses.toStringAsFixed(2)}',
                  color: Colors.purple,
                  icon: Icons.receipt_long,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ResponsiveCardGrid(
              cards: [
                _SummaryCard(
                  title: 'Total Billed',
                  value: 'Rs. ${billsSummary.totalBilled.toStringAsFixed(2)}',
                  color: Colors.indigo,
                  icon: Icons.receipt_outlined,
                ),
                _SummaryCard(
                  title: 'Bills Paid',
                  value: 'Rs. ${billsSummary.totalPaid.toStringAsFixed(2)}',
                  color: Colors.teal,
                  icon: Icons.check_circle_outline,
                ),
                _SummaryCard(
                  title: 'Active Schemes',
                  value: '$activeSchemesCount',
                  color: Colors.indigo,
                  icon: Icons.architecture,
                ),
                _SummaryCard(
                  title: 'Completed',
                  value: '$completedSchemesCount',
                  color: Colors.green,
                  icon: Icons.task_alt_outlined,
                ),
                _SummaryCard(
                  title: 'Incomplete',
                  value: '$incompleteSchemesCount',
                  color: Colors.red,
                  icon: Icons.warning_amber_outlined,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ----------------------------------------------------------------
            // Quick Actions
            // ----------------------------------------------------------------
            const _SectionTitle('Quick Actions'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => showTransactionForm(
                    context,
                    txRepo,
                    people,
                    schemes,
                    sites,
                  ),
                  icon: const Icon(Icons.add_card),
                  label: const Text('Add Transaction'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      showExpenseForm(context, expRepo, sites, schemes, people),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Add Expense'),
                ),
                OutlinedButton.icon(
                  onPressed: roles.isEmpty
                      ? null
                      : () => showPersonForm(context, peopleRepo, roles),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Add Person'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showSiteForm(context, sitesRepo),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add Site'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      showSchemeForm(context, schemesRepo, sites, people),
                  icon: const Icon(Icons.assignment_add),
                  label: const Text('Add Scheme'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ----------------------------------------------------------------
            // Operational Summary
            // ----------------------------------------------------------------
            const _SectionTitle('Operational Summary'),
            const SizedBox(height: 12),
            _ResponsiveCardGrid(
              cards: [
                _StatCard(
                  title: 'Active Sites',
                  count: '$activeSitesCount / ${sites.length}',
                  icon: Icons.location_city,
                  color: Colors.teal,
                ),
                _StatCard(
                  title: 'Active Schemes',
                  count: '$activeSchemesCount / ${schemes.length}',
                  icon: Icons.assignment,
                  color: Colors.indigo,
                ),
                _StatCard(
                  title: 'Workforce',
                  count: '${people.length} People',
                  icon: Icons.people,
                  color: Colors.deepOrange,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ----------------------------------------------------------------
            // Upcoming Reminders
            // ----------------------------------------------------------------
            const _SectionTitle('Upcoming Reminders'),
            const SizedBox(height: 12),
            if (upcomingReminders.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No upcoming reminders. All clear!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...upcomingReminders.map(
                (r) => _ReminderTile(
                  reminder: r,
                  onMarkDone: () => remindersRepo.markDone(r.id),
                ),
              ),

            const SizedBox(height: 24),

            // ----------------------------------------------------------------
            // Schemes & Budget Progress
            // ----------------------------------------------------------------
            const _SectionTitle('Schemes & Budget Progress'),
            const SizedBox(height: 12),
            if (schemes.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No schemes found. Add a scheme to track budget.',
                  ),
                ),
              )
            else
              ...schemes
                  .take(5)
                  .map(
                    (scheme) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(
                              scheme.schemeCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(scheme.name)),
                            Text('Rs. ${scheme.formattedBudget}'),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: (scheme.progressPercentage / 100.0).clamp(
                                0.0,
                                1.0,
                              ),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Status: ${scheme.status}'),
                                Text(
                                  '${scheme.progressPercentage.round()}% Completed',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reminder tile for dashboard
// ---------------------------------------------------------------------------

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder, required this.onMarkDone});

  final ReminderModel reminder;
  final VoidCallback onMarkDone;

  @override
  Widget build(BuildContext context) {
    final overdue = reminder.isOverdue;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Checkbox(value: false, onChanged: (_) => onMarkDone()),
        title: Text(
          reminder.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: overdue ? Colors.red : null,
          ),
        ),
        subtitle: reminder.dueAt == null
            ? null
            : Text(
                overdue
                    ? 'Overdue — ${_formatDateTime(reminder.dueAt!)}'
                    : 'Due ${_formatDateTime(reminder.dueAt!)}',
                style: TextStyle(
                  color: overdue ? Colors.red : Colors.grey,
                  fontSize: 12,
                ),
              ),
        trailing: _PriorityDot(priority: reminder.priority),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final date = _formatDate(dt);
    if (local.hour == 0 && local.minute == 0) return date;
    return '$date ${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      'high' => Colors.red,
      'low' => Colors.green,
      _ => Colors.orange,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ---------------------------------------------------------------------------
// Responsive card grid — 2 columns on narrow, all in one row on wide
// ---------------------------------------------------------------------------

class _ResponsiveCardGrid extends StatelessWidget {
  const _ResponsiveCardGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        if (isWide) {
          return Row(
            children: cards
                .map(
                  (c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: c,
                    ),
                  ),
                )
                .toList(),
          );
        }
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.4,
          children: cards,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Section title
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
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
            const SizedBox(height: 6),
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

// ---------------------------------------------------------------------------
// Stat card
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String title;
  final String count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              count,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
