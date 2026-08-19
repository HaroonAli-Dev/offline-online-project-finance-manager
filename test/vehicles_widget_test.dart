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
import 'package:offline_finance_management_app/src/features/vehicles/domain/vehicle_model.dart';
import 'package:offline_finance_management_app/src/features/vehicles/presentation/vehicles_providers.dart';

void main() {
  testWidgets('renders the Vehicles screen and vehicle cards', (
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
            (ref) => Stream<List<ExpenseModel>>.value(const []),
          ),
          vehiclesProvider.overrideWith(
            (ref) => Stream<List<VehicleModel>>.value([
              const VehicleModel(
                id: 'v1',
                vehicleNumber: 'LEB-5544',
                makeModel: 'CAT Dumper Truck',
                vehicleType: 'dumper',
                status: 'active',
              ),
            ]),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    final vehiclesNav = find.text('Vehicles');
    expect(vehiclesNav, findsWidgets);
    await tester.tap(vehiclesNav.last);
    await tester.pumpAndSettle();

    expect(find.text('Vehicles & Drivers'), findsOneWidget);
    expect(find.text('LEB-5544'), findsOneWidget);
    expect(find.text('CAT Dumper Truck'), findsOneWidget);
    expect(find.text('Add Vehicle'), findsOneWidget);
  });
}
