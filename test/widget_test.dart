import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/providers/hint_preferences_provider.dart';
import 'package:offline_finance_management_app/src/features/people/domain/person_summary.dart';
import 'package:offline_finance_management_app/src/features/people/domain/role_definition.dart';
import 'package:offline_finance_management_app/src/features/people/presentation/people_page.dart';
import 'package:offline_finance_management_app/src/features/people/presentation/people_providers.dart';

void main() {
  testWidgets('renders the People screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          peopleProvider.overrideWith(
            (ref) => Stream<List<PersonSummary>>.value(const []),
          ),
          rolesProvider.overrideWith(
            (ref) => Stream<List<RoleDefinition>>.value(const [
              RoleDefinition(code: 'engineer', displayName: 'Engineer'),
            ]),
          ),
        ],
        child: const MaterialApp(home: PeoplePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('People'), findsWidgets);
    expect(find.text('Add person'), findsOneWidget);
  });

  test('guide visibility starts hidden and resets with a clear action', () {
    final notifier = PageGuideVisibilityNotifier();

    expect(notifier.state, isEmpty);
    expect(notifier.isVisible('people'), isFalse);

    notifier.toggleGuideVisible('people');
    expect(notifier.isVisible('people'), isTrue);

    notifier.clearAll();
    expect(notifier.state, isEmpty);
    expect(notifier.isVisible('people'), isFalse);
  });
}
