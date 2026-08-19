import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/app/app.dart';
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
  testWidgets('renders the Transactions screen and summary metrics', (
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
            (ref) => Stream<List<TransactionModel>>.value([
              TransactionModel(
                id: 'tx1',
                transactionCode: 'TXN-001',
                transactionDate: DateTime(2026, 3, 1),
                type: 'received',
                amount: 100000.0,
                purpose: 'Government Grant Received',
                paymentMethod: 'bank_transfer',
              ),
            ]),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    final txnsNav = find.text('Transactions');
    expect(txnsNav, findsWidgets);
    await tester.tap(txnsNav.last);
    await tester.pumpAndSettle();

    expect(find.text('Financial Transactions'), findsOneWidget);
    expect(find.text('Government Grant Received'), findsOneWidget);
    expect(find.text('Total Received'), findsOneWidget);
    expect(find.text('Add Transaction'), findsOneWidget);
  });
}
