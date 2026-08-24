import 'package:flutter/widgets.dart';

import '../core/config/supabase_config.dart';
import '../core/database/app_database.dart';
import 'startup_app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  final databaseFuture = _initializeDatabase();
  runApp(StartupApp(databaseFuture: databaseFuture));
}

Future<AppDatabase> _initializeDatabase() async {
  final database = AppDatabase();
  try {
    await database.validateConnection();
    return database;
  } catch (_) {
    await database.close();
    rethrow;
  }
}
