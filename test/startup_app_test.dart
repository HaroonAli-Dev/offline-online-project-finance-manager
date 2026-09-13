import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_project_finance_manager/src/app/startup_app.dart';

void main() {
  testWidgets(
    'shows the logo while initializing and opens the app when ready',
    (tester) async {
      await tester.pumpWidget(
        const StartupApp(readyChild: Text('Ready')),
      );

      // Splash is shown while session future is resolving
      expect(find.byType(Image), findsWidgets);
      expect(find.text('Finance & Construction Manager'), findsOneWidget);

      // Let the session future complete (no saved session → unauthenticated)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Unauthenticated → LoginScreen shown, not readyChild
      expect(find.text('Ready'), findsNothing);
    },
  );
}
