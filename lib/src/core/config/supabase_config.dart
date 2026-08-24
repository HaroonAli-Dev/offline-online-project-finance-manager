import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration and initialization manager for Supabase services.
///
/// Uses compile-time environment variables (`--dart-define`) to avoid hardcoded credentials.
/// When parameters are not provided or empty, the application operates safely in offline-only mode.
class SupabaseConfig {
  SupabaseConfig._();

  /// URL for the Supabase project backend.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Anonymous/publishable API key for the Supabase project.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Whether valid Supabase parameters were provided at compile/run time.
  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// Whether Supabase has successfully initialized its client instance.
  static bool get isInitialized => isConfigured && _isInitialized;
  static bool _isInitialized = false;

  /// Initializes Supabase with `--dart-define` credentials if available.
  ///
  /// Safe to call on all supported platforms (Android, Windows, Web, macOS, Linux, iOS).
  /// If credentials are missing or empty, initialization is skipped without throwing an error,
  /// preserving full offline capability.
  static Future<void> initialize({
    String? url,
    String? anonKey,
  }) async {
    final effectiveUrl = url ?? supabaseUrl;
    final effectiveAnonKey = anonKey ?? supabaseAnonKey;

    if (effectiveUrl.trim().isEmpty || effectiveAnonKey.trim().isEmpty) {
      debugPrint(
        'SupabaseConfig: SUPABASE_URL or SUPABASE_ANON_KEY is missing. '
        'Continuing in offline-only mode.',
      );
      _isInitialized = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: effectiveUrl.trim(),
        anonKey: effectiveAnonKey.trim(),
      );
      _isInitialized = true;
      debugPrint('SupabaseConfig: Supabase initialized successfully.');
    } catch (e, st) {
      _isInitialized = false;
      debugPrint('SupabaseConfig: Failed to initialize Supabase: $e\n$st');
      // Do not rethrow here so that the app remains fully functional offline
    }
  }

  /// Gets the [SupabaseClient] instance if initialized, or throws a descriptive [StateError].
  static SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError(
        'Supabase has not been initialized. '
        'Ensure SUPABASE_URL and SUPABASE_ANON_KEY are provided via --dart-define '
        'and initialize() has completed.',
      );
    }
    return Supabase.instance.client;
  }
}
