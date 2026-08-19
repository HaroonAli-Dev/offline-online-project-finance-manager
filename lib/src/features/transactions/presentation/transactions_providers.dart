import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_provider.dart';
import '../data/transactions_repository.dart';
import '../domain/transaction_model.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository(ref.watch(appDatabaseProvider), const Uuid());
});

final transactionsSearchProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final transactionsTypeFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final transactionsPersonFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final transactionsSchemeFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final transactionsSiteFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final transactionsProvider = StreamProvider.autoDispose<List<TransactionModel>>(
  (ref) {
    final searchQuery = ref.watch(transactionsSearchProvider);
    final typeFilter = ref.watch(transactionsTypeFilterProvider);
    final personFilter = ref.watch(transactionsPersonFilterProvider);
    final schemeFilter = ref.watch(transactionsSchemeFilterProvider);
    final siteFilter = ref.watch(transactionsSiteFilterProvider);

    return ref
        .watch(transactionsRepositoryProvider)
        .watchTransactions(
          searchQuery: searchQuery,
          typeFilter: typeFilter,
          personFilter: personFilter,
          schemeFilter: schemeFilter,
          siteFilter: siteFilter,
        );
  },
);

class TransactionSummaryMetrics {
  const TransactionSummaryMetrics({
    required this.totalReceived,
    required this.totalPaid,
    required this.balance,
  });

  final double totalReceived;
  final double totalPaid;
  final double balance;
}

final transactionsSummaryProvider =
    Provider.autoDispose<TransactionSummaryMetrics>((ref) {
      final transactions =
          ref.watch(transactionsProvider).valueOrNull ?? const [];
      double received = 0.0;
      double paid = 0.0;

      for (final txn in transactions) {
        if (txn.isReceived) {
          received += txn.amount;
        } else if (txn.isPaid) {
          paid += txn.amount;
        }
      }

      return TransactionSummaryMetrics(
        totalReceived: received,
        totalPaid: paid,
        balance: received - paid,
      );
    });

/// All transactions unfiltered — used by dashboard summary.
final _allTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  return ref.watch(transactionsRepositoryProvider).watchTransactions();
});

/// Unfiltered transaction summary for the Dashboard.
/// Reads all transactions regardless of any active page filters.
final dashboardTransactionSummaryProvider = Provider<TransactionSummaryMetrics>(
  (ref) {
    final transactions =
        ref.watch(_allTransactionsProvider).valueOrNull ?? const [];
    double received = 0.0;
    double paid = 0.0;
    for (final txn in transactions) {
      if (txn.isReceived) received += txn.amount;
      if (txn.isPaid) paid += txn.amount;
    }
    return TransactionSummaryMetrics(
      totalReceived: received,
      totalPaid: paid,
      balance: received - paid,
    );
  },
);
