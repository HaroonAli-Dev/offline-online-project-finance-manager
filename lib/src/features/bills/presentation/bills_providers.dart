import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_value_extensions.dart';

import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_provider.dart';
import '../data/bills_repository.dart';
import '../domain/bill_model.dart';
import '../domain/bill_totals.dart';

final billsRepositoryProvider = Provider<BillsRepository>((ref) {
  return BillsRepository(ref.watch(appDatabaseProvider), const Uuid());
});

final billsSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final billsSchemeFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final billsTypeFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final billsStatusFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final billsProvider = StreamProvider.autoDispose<List<BillModel>>((ref) {
  final search = ref.watch(billsSearchProvider);
  final scheme = ref.watch(billsSchemeFilterProvider);
  final type = ref.watch(billsTypeFilterProvider);
  final status = ref.watch(billsStatusFilterProvider);

  return ref
      .watch(billsRepositoryProvider)
      .watchBills(
        searchQuery: search,
        schemeFilter: scheme,
        typeFilter: type,
        statusFilter: status,
      );
});

/// Bills for a specific scheme — used by SchemeBillsPage.
final schemeBillsProvider = StreamProvider.autoDispose
    .family<List<BillModel>, String>((ref, schemeId) {
      return ref.watch(billsRepositoryProvider).watchBillsByScheme(schemeId);
    });

/// Bill totals for a specific scheme — used by SchemeBillsPage.
final schemeBillTotalsProvider = FutureProvider.autoDispose
    .family<BillTotals, String>((ref, schemeId) {
      // Recompute whenever bills change.
      ref.watch(schemeBillsProvider(schemeId));
      return ref.watch(billsRepositoryProvider).getBillTotals(schemeId);
    });

/// Aggregate bill totals across ALL schemes — used by the Dashboard.
final dashboardBillsSummaryProvider =
    Provider<({double totalBilled, double totalPaid})>((ref) {
      final bills = ref.watch(billsProvider).valueOrNull ?? const [];
      double billed = 0;
      double paid = 0;
      for (final b in bills) {
        billed += b.amount;
        if (b.status == 'paid') paid += b.amount;
      }
      return (totalBilled: billed, totalPaid: paid);
    });
