import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/app/app.dart';
import 'package:offline_finance_management_app/src/features/people/domain/person_summary.dart';
import 'package:offline_finance_management_app/src/features/people/domain/role_definition.dart';
import 'package:offline_finance_management_app/src/features/people/presentation/people_providers.dart';
import 'package:offline_finance_management_app/src/features/sites/domain/site_model.dart';
import 'package:offline_finance_management_app/src/features/sites/presentation/sites_providers.dart';

void main() {
  testWidgets('renders the Sites screen and navigation', (
    WidgetTester tester,
  ) async {
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
            (ref) => Stream<List<SiteModel>>.value(const [
              SiteModel(
                id: 's1',
                name: 'Test Highway Site',
                roadInfo: 'KM 5',
                status: 'active',
              ),
            ]),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('People'), findsWidgets);

    final sitesNav = find.text('Sites');
    expect(sitesNav, findsWidgets);
    await tester.tap(sitesNav.first);
    await tester.pumpAndSettle();

    expect(find.text('Test Highway Site'), findsOneWidget);
    expect(find.text('Add site'), findsOneWidget);
  });
}
