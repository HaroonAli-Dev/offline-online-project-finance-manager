import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/export_service.dart';
import '../../expenses/presentation/expenses_providers.dart';
import '../../transactions/presentation/transactions_providers.dart';

class BackupExportDialog extends ConsumerWidget {
  const BackupExportDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.import_export),
          SizedBox(width: 8),
          Text('Data Export & Backup'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export CSV Reports',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.table_chart_outlined,
                color: Colors.green,
              ),
              title: const Text('Export Transactions (CSV)'),
              subtitle: const Text(
                'Save financial ledger to Excel/CSV spreadsheet',
              ),
              onTap: () async {
                final txns =
                    ref.read(transactionsProvider).valueOrNull ?? const [];
                final path = await ExportService.exportTransactionsToCsv(txns);
                if (path != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Transactions exported to $path')),
                  );
                  Navigator.pop(context);
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.table_chart_outlined,
                color: Colors.purple,
              ),
              title: const Text('Export Expenses (CSV)'),
              subtitle: const Text(
                'Save category expense log to Excel/CSV spreadsheet',
              ),
              onTap: () async {
                final exps = ref.read(expensesProvider).valueOrNull ?? const [];
                final path = await ExportService.exportExpensesToCsv(exps);
                if (path != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Expenses exported to $path')),
                  );
                  Navigator.pop(context);
                }
              },
            ),
            const Divider(),
            Text(
              'Database Backup & Restore',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.backup_outlined, color: Colors.blue),
              title: const Text('Backup Database File'),
              subtitle: const Text('Save a copy of your offline database file'),
              onTap: () async {
                try {
                  final path = await ExportService.backupDatabase();
                  if (path != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Database backed up to $path')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Backup failed: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore_outlined, color: Colors.orange),
              title: const Text('Restore Database File'),
              subtitle: const Text('Overwrite current data from a backup file'),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Restore Database?'),
                    content: const Text(
                      'Restoring will overwrite your current app data with the selected backup file. Please restart the app after restoring.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Restore'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;

                final success = await ExportService.restoreDatabase();
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Database restored! Please restart the app.',
                      ),
                    ),
                  );
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
