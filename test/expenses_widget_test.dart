import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/app/app.dart';
import 'package:offline_finance_management_app/src/features/expenses/domain/expense_model.dart';
import 'package:offline_finance_management_app/src/features/expenses/presentation/expenses_providers.dart';
import 'package:offline_finance_management_app/src/features/people/domain/person_summary.dart';
import 'package:offline_finance_management_app/src/features/people/domain/role_definition.dart';
import 'package:offline_finance_management_app/src/features/people/presentation/people_providers.dart';
import 'package:offline_finance_management_app/src/features/schemes/domain/scheme_model.dart';
import 'package:offline_finance_management_app/src/features/schemes/presentation/schemes_providers.dart';
import 'package:offline_finance_management_app/src/features/sites/domain/site_model.dart';
import 'package:offline_finance_management_app/src/features/sites/presentation/sites_providers.dart';
import 'package:offline_finance_management_app/src/features/transactions/domain/transaction_model.dart';
import 'package:offline_finance_management_app/src/features/transactions/presentation/transactions_providers.dart';

void main() {
  testWidgets('renders the Expenses screen and total summary', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          peopleProvider.overrideWith(
            (ref) => Stream<List<PersonSummary>>.value(const []),
          ),
          rolesProvider.overrideWith(
            (ref) => Stream<List<RoleDefinition>>.value(const []),
          ),
          sitesProvider.overrideWith(
            (ref) => Stream<List<SiteModel>>.value(const []),
          ),
          schemesProvider.overrideWith(
            (ref) => Stream<List<SchemeModel>>.value(const []),
          ),
          transactionsProvider.overrideWith(
            (ref) => Stream<List<TransactionModel>>.value(const []),
          ),
          expensesProvider.overrideWith(
            (ref) => Stream<List<ExpenseModel>>.value([
              ExpenseModel(
                id: 'ex1',
                expenseCode: 'EXP-001',
                expenseDate: DateTime(2026, 3, 10),
                category: 'office',
                amount: 750.0,
                purpose: 'Office Coffee & Snacks',
              ),
            ]),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    final expsNav = find.text('Expenses');
    expect(expsNav, findsWidgets);
    await tester.tap(expsNav.last);
    await tester.pumpAndSettle();

    expect(find.text('Total Expenses Recorded'), findsOneWidget);
    expect(find.text('Office Coffee & Snacks'), findsOneWidget);
    expect(find.text('Add Expense'), findsOneWidget);
  });
}
