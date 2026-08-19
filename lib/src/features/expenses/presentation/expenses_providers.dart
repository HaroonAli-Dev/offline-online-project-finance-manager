import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_provider.dart';
import '../data/expenses_repository.dart';
import '../domain/expense_model.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(ref.watch(appDatabaseProvider), const Uuid());
});

final expensesSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final expensesCategoryFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final expensesSiteFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final expensesSchemeFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final expensesPersonFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final expensesProvider = StreamProvider.autoDispose<List<ExpenseModel>>((ref) {
  final searchQuery = ref.watch(expensesSearchProvider);
  final categoryFilter = ref.watch(expensesCategoryFilterProvider);
  final siteFilter = ref.watch(expensesSiteFilterProvider);
  final schemeFilter = ref.watch(expensesSchemeFilterProvider);
  final personFilter = ref.watch(expensesPersonFilterProvider);

  return ref
      .watch(expensesRepositoryProvider)
      .watchExpenses(
        searchQuery: searchQuery,
        categoryFilter: categoryFilter,
        siteFilter: siteFilter,
        schemeFilter: schemeFilter,
        personFilter: personFilter,
      );
});

final totalExpensesSummaryProvider = Provider.autoDispose<double>((ref) {
  final expenses = ref.watch(expensesProvider).valueOrNull ?? const [];
  double total = 0.0;
  for (final exp in expenses) {
    total += exp.amount;
  }
  return total;
});

/// All expenses unfiltered — used by dashboard summary.
final _allExpensesProvider = StreamProvider<List<ExpenseModel>>((ref) {
  return ref.watch(expensesRepositoryProvider).watchExpenses();
});

/// Unfiltered total expenses for the Dashboard.
final dashboardTotalExpensesProvider = Provider<double>((ref) {
  final expenses = ref.watch(_allExpensesProvider).valueOrNull ?? const [];
  double total = 0.0;
  for (final exp in expenses) {
    total += exp.amount;
  }
  return total;
});
