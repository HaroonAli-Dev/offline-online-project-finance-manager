import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:offline_finance_management_app/src/features/bills/presentation/bills_providers.dart';
import 'package:offline_finance_management_app/src/features/expenses/presentation/expenses_providers.dart';
import 'package:offline_finance_management_app/src/features/people/domain/person_summary.dart';
import 'package:offline_finance_management_app/src/features/people/domain/role_definition.dart';
import 'package:offline_finance_management_app/src/features/people/presentation/people_providers.dart';
import 'package:offline_finance_management_app/src/features/reminders/domain/reminder_model.dart';
import 'package:offline_finance_management_app/src/features/reminders/presentation/reminders_providers.dart';
import 'package:offline_finance_management_app/src/features/schemes/domain/scheme_model.dart';
import 'package:offline_finance_management_app/src/features/schemes/presentation/schemes_providers.dart';
import 'package:offline_finance_management_app/src/features/sites/domain/site_model.dart';
import 'package:offline_finance_management_app/src/features/sites/presentation/sites_providers.dart';
import 'package:offline_finance_management_app/src/features/transactions/presentation/transactions_providers.dart';

void main() {
  const metrics = TransactionSummaryMetrics(
    totalReceived: 125000,
    totalPaid: 0,
    balance: 125000,
  );

  final emptyDataOverrides = [
    dashboardTransactionSummaryProvider.overrideWithValue(metrics),
    dashboardTotalExpensesProvider.overrideWithValue(2500),
    dashboardBillsSummaryProvider.overrideWithValue((
      totalBilled: 0.0,
      totalPaid: 0.0,
    )),
    peopleProvider.overrideWith((ref) => Stream.value(const <PersonSummary>[])),
    rolesProvider.overrideWith((ref) => Stream.value(const <RoleDefinition>[])),
    sitesProvider.overrideWith((ref) => Stream.value(const <SiteModel>[])),
    schemesProvider.overrideWith((ref) => Stream.value(const <SchemeModel>[])),
  ];

  testWidgets('loads local statistics and upcoming reminders', (tester) async {
    final reminder = ReminderModel(
      id: 'dashboard-reminder',
      title: 'Inspect foundation',
      dueAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
      priority: 'high',
      isDone: false,
      createdAt: DateTime.now().toUtc(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...emptyDataOverrides,
          dashboardUpcomingRemindersProvider.overrideWith(
            (ref) => Stream.value([reminder]),
          ),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Rs. 125000.00'), findsWidgets);
    expect(find.text('Rs. 2500.00'), findsWidgets);
    expect(find.text('Inspect foundation'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('builds without overflow at a phone width with empty data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...emptyDataOverrides,
          dashboardUpcomingRemindersProvider.overrideWith(
            (ref) => Stream.value(const <ReminderModel>[]),
          ),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No upcoming reminders. All clear!'), findsOneWidget);
    expect(
      find.text('No schemes found. Add a scheme to track budget.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
