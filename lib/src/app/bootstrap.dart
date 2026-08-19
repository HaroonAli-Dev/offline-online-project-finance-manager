import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import '../core/database/app_database.dart';
import '../core/providers/database_provider.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  await database.validateConnection();

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const App(),
    ),
  );
}
