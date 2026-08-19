import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/expenses/domain/expense_model.dart';
import '../../features/transactions/domain/transaction_model.dart';

// Platform-conditional import helper for dart:io File operations
import 'export_file_helper_stub.dart'
    if (dart.library.io) 'export_file_helper_io.dart';

class ExportService {
  /// Export Transactions to CSV file via FilePicker / Web Blob Download
  static Future<String?> exportTransactionsToCsv(
    List<TransactionModel> transactions,
  ) async {
    final rows = <List<dynamic>>[
      [
        'Code',
        'Date',
        'Type',
        'Amount (Rs)',
        'Purpose',
        'Payment Method',
        'Reference No',
        'Person',
        'Scheme',
        'Site',
        'Remarks',
      ],
    ];

    for (final t in transactions) {
      rows.add([
        t.transactionCode,
        '${t.transactionDate.year}-${t.transactionDate.month.toString().padLeft(2, '0')}-${t.transactionDate.day.toString().padLeft(2, '0')}',
        t.isReceived ? 'Received' : 'Paid',
        t.amount,
        t.purpose,
        t.paymentMethodDisplay,
        t.referenceNumber ?? '',
        t.personName ?? '',
        t.schemeName ?? '',
        t.siteName ?? '',
        t.remarks ?? '',
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final fileName =
        'transactions_report_${DateTime.now().millisecondsSinceEpoch}.csv';

    if (kIsWeb) {
      final uri = Uri.dataFromString(
        csvData,
        mimeType: 'text/csv',
        encoding: utf8,
      );
      await launchUrl(uri);
      return 'Downloaded via browser';
    }

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Transactions CSV Report',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null) return null;

    await writeStringToFile(result, csvData);
    return result;
  }

  /// Export Expenses to CSV file via FilePicker / Web Blob Download
  static Future<String?> exportExpensesToCsv(
    List<ExpenseModel> expenses,
  ) async {
    final rows = <List<dynamic>>[
      [
        'Code',
        'Date',
        'Category',
        'Amount (Rs)',
        'Purpose',
        'Site',
        'Scheme',
        'Person',
        'Remarks',
      ],
    ];

    for (final e in expenses) {
      rows.add([
        e.expenseCode,
        '${e.expenseDate.year}-${e.expenseDate.month.toString().padLeft(2, '0')}-${e.expenseDate.day.toString().padLeft(2, '0')}',
        e.categoryDisplay,
        e.amount,
        e.purpose,
        e.siteName ?? '',
        e.schemeName ?? '',
        e.personName ?? '',
        e.remarks ?? '',
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final fileName =
        'expenses_report_${DateTime.now().millisecondsSinceEpoch}.csv';

    if (kIsWeb) {
      final uri = Uri.dataFromString(
        csvData,
        mimeType: 'text/csv',
        encoding: utf8,
      );
      await launchUrl(uri);
      return 'Downloaded via browser';
    }

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Expenses CSV Report',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null) return null;

    await writeStringToFile(result, csvData);
    return result;
  }

  /// Backup database file to a location chosen by user
  static Future<String?> backupDatabase() async {
    if (kIsWeb) {
      throw Exception(
        'Database backup file download is not supported on Web browser.',
      );
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(appDocDir.path, 'finance_construction.sqlite');
    final altDbPath = p.join(appDocDir.path, 'finance_construction');

    final sourcePath = await fileExists(dbPath)
        ? dbPath
        : (await fileExists(altDbPath) ? altDbPath : null);

    if (sourcePath == null) {
      throw Exception('Database file not found yet.');
    }

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Backup Copy of Database',
      fileName:
          'finance_construction_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite',
      type: FileType.any,
    );

    if (result == null) return null;

    await copyFileTo(sourcePath, result);
    return result;
  }

  /// Restore database from selected sqlite backup file
  static Future<bool> restoreDatabase() async {
    if (kIsWeb) {
      throw Exception('Database restore is not supported on Web browser.');
    }

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Backup Database File (.sqlite)',
      type: FileType.any,
    );

    if (result == null || result.files.single.path == null) return false;

    final selectedPath = result.files.single.path!;
    final appDocDir = await getApplicationDocumentsDirectory();
    final targetDbPath = p.join(appDocDir.path, 'finance_construction.sqlite');

    await copyFileTo(selectedPath, targetDbPath);
    return true;
  }
}
