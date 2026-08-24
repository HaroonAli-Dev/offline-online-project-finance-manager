import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

/// Provider exposing the [AuthService] singleton.
final authServiceProvider = Provider<AuthService>((ref) {
  return const AuthService();
});

/// Immutable state representation of user authentication.
class AppAuthState {
  const AppAuthState({
    this.session,
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isOfflineBypass = false,
  });

  final Session? session;
  final User? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isOfflineBypass;

  bool get isAuthenticated => user != null || isOfflineBypass;

  AppAuthState copyWith({
    Session? Function()? session,
    User? Function()? user,
    bool? isLoading,
    String? Function()? errorMessage,
    bool? isOfflineBypass,
  }) {
    return AppAuthState(
      session: session != null ? session() : this.session,
      user: user != null ? user() : this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      isOfflineBypass: isOfflineBypass ?? this.isOfflineBypass,
    );
  }
}

/// Notifier managing authentication state and actions.
class AuthNotifier extends Notifier<AppAuthState> {
  @override
  AppAuthState build() {
    final authService = ref.watch(authServiceProvider);

    // Subscribe to Supabase auth state change events if active.
    final subscription = authService.authStateChanges.listen((data) {
      state = state.copyWith(
        session: () => data.session,
        user: () => data.session?.user,
        isLoading: false,
        errorMessage: () => null,
      );
    });

    ref.onDispose(subscription.cancel);

    // Initial state: restore session if available
    return AppAuthState(
      session: authService.currentSession,
      user: authService.currentUser,
    );
  }

  /// Sign in with email and password.
  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final authService = ref.read(authServiceProvider);
      final response = await authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(
        session: () => response.session,
        user: () => response.user ?? response.session?.user,
        isLoading: false,
        errorMessage: () => null,
        isOfflineBypass: false,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  /// Sign up with email and password.
  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final authService = ref.read(authServiceProvider);
      final response = await authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(
        session: () => response.session,
        user: () => response.user ?? response.session?.user,
        isLoading: false,
        errorMessage: () => null,
        isOfflineBypass: false,
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  /// Enter offline guest mode when Supabase credentials or network are not available.
  void continueOffline() {
    state = state.copyWith(
      isOfflineBypass: true,
      errorMessage: () => null,
    );
  }

  /// Sign out current user.
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      state = const AppAuthState();
    } catch (e) {
      state = const AppAuthState();
    }
  }

  /// Clear any error message.
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: () => null);
    }
  }
}

/// Provider exposing [AppAuthState] and actions via [AuthNotifier].
final authStateProvider = NotifierProvider<AuthNotifier, AppAuthState>(() {
  return AuthNotifier();
});

/// Convenience provider to check if current user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isAuthenticated;
});

/// Convenience provider for current user email or label.
final currentUserEmailProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.isOfflineBypass) {
    return 'Offline Mode';
  }
  return authState.user?.email;
});
