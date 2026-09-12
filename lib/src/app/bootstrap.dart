import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/config/supabase_config.dart';
import 'startup_app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(SupabaseConfig.initialize());
  runApp(const StartupApp());
}
