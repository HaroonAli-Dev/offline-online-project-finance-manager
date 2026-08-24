import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/config/supabase_config.dart';

void main() {
  group('SupabaseConfig', () {
    test('reports unconfigured when environment variables are empty', () {
      expect(SupabaseConfig.supabaseUrl, isEmpty);
      expect(SupabaseConfig.supabaseAnonKey, isEmpty);
      expect(SupabaseConfig.isConfigured, isFalse);
      expect(SupabaseConfig.isInitialized, isFalse);
    });

    test('throws StateError when accessing client without initialization', () {
      expect(
        () => SupabaseConfig.client,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Supabase has not been initialized'),
          ),
        ),
      );
    });

    test('initialize() completes safely without throwing when credentials are empty', () async {
      await SupabaseConfig.initialize(url: '', anonKey: '');
      expect(SupabaseConfig.isInitialized, isFalse);
    });

    test('initialize() completes safely without throwing when credentials with whitespace are passed', () async {
      await SupabaseConfig.initialize(url: '   ', anonKey: '   ');
      expect(SupabaseConfig.isInitialized, isFalse);
    });
  });
}
