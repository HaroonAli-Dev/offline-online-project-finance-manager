import 'dart:ui';

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

void main() {
  testWidgets('renders the Schemes screen and navigates to it', (
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
            (ref) => Stream<List<SchemeModel>>.value(const [
              SchemeModel(
                id: 'sc1',
                schemeCode: 'SCH-99',
                name: 'Test Flyover Scheme',
                budget: 2500000.0,
                status: 'working',
                progressPercentage: 45.0,
              ),
            ]),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    final schemesNav = find.text('Schemes');
    expect(schemesNav, findsWidgets);
    await tester.tap(schemesNav.first);
    await tester.pumpAndSettle();

    expect(find.text('Test Flyover Scheme'), findsOneWidget);
    expect(find.text('SCH-99'), findsOneWidget);
    expect(find.text('Add scheme'), findsOneWidget);
  });
}
