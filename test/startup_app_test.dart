import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/app/startup_app.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';

void main() {
  testWidgets(
    'shows the logo while initializing and opens the app when ready',
    (tester) async {
      final completer = Completer<AppDatabase>();
      await tester.pumpWidget(
        StartupApp(
          databaseFuture: completer.future,
          readyChild: const Text('Ready'),
        ),
      );

      expect(find.byType(Image), findsWidgets);
      expect(find.text('Finance & Construction Manager'), findsOneWidget);

      final database = AppDatabase(NativeDatabase.memory());
      completer.complete(database);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Ready'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await database.close();
    },
  );
}
