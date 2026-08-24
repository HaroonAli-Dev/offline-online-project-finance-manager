import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

/// Service managing Supabase authentication operations.
///
/// If Supabase is not configured (e.g. offline-only run without `--dart-define`),
/// operations handle the unconfigured state gracefully.
class AuthService {
  const AuthService();

  /// The underlying Supabase client, or `null` if not configured/initialized.
  SupabaseClient? get _client =>
      SupabaseConfig.isInitialized ? SupabaseConfig.client : null;

  /// Current active Supabase session, if any.
  Session? get currentSession => _client?.auth.currentSession;

  /// Current authenticated user, if any.
  User? get currentUser => _client?.auth.currentUser;

  /// Whether a user is currently signed in to Supabase.
  bool get isAuthenticated => currentUser != null;

  /// Stream of Supabase auth state changes.
  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();

  /// Signs in a user with email and password.
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthException(
        'Supabase is not configured. Please supply SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
      );
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        'Failed to sign in: ${e.toString().replaceAll(RegExp(r'^Exception: '), '')}',
      );
    }
  }

  /// Signs up a new user with email and password.
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthException(
        'Supabase is not configured. Please supply SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
      );
    }

    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        'Failed to sign up: ${e.toString().replaceAll(RegExp(r'^Exception: '), '')}',
      );
    }
  }

  /// Signs out the current authenticated user.
  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;

    try {
      await client.auth.signOut();
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('AuthService: Failed to sign out cleanly: $e');
    }
  }
}
