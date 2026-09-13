import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/local_session_service.dart';

/// Provider exposing the [AuthService] singleton.
final authServiceProvider = Provider<AuthService>((ref) {
  return const AuthService();
});

/// Provider exposing the [LocalSessionService] singleton.
final localSessionServiceProvider = Provider<LocalSessionService>((ref) {
  return LocalSessionService.instance;
});

/// Optional provider supplying pre-loaded session data from startup restoration gate.
final initialRestoredSessionProvider = Provider<LocalSessionData?>(
  (ref) => null,
);

/// Immutable state representation of user authentication.
class AppAuthState {
  const AppAuthState({
    this.session,
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.emailError,
    this.passwordError,
    this.isOfflineBypass = false,
    this.rememberMe = false,
    this.isRestoredOffline = false,
  });

  final Session? session;
  final User? user;
  final bool isLoading;
  final String? errorMessage;
  final String? emailError;
  final String? passwordError;
  final bool isOfflineBypass;
  final bool rememberMe;
  final bool isRestoredOffline;

  bool get isAuthenticated => user != null || isOfflineBypass;

  AppAuthState copyWith({
    Session? Function()? session,
    User? Function()? user,
    bool? isLoading,
    String? Function()? errorMessage,
    String? Function()? emailError,
    String? Function()? passwordError,
    bool? isOfflineBypass,
    bool? rememberMe,
    bool? isRestoredOffline,
  }) {
    return AppAuthState(
      session: session != null ? session() : this.session,
      user: user != null ? user() : this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      emailError: emailError != null ? emailError() : this.emailError,
      passwordError: passwordError != null
          ? passwordError()
          : this.passwordError,
      isOfflineBypass: isOfflineBypass ?? this.isOfflineBypass,
      rememberMe: rememberMe ?? this.rememberMe,
      isRestoredOffline: isRestoredOffline ?? this.isRestoredOffline,
    );
  }
}

/// Notifier managing authentication state and actions.
class AuthNotifier extends Notifier<AppAuthState> {
  bool _isSigningUp = false;

  void restoreOfflineSession(LocalSessionData session) {
    state = AppAuthState(
      user: User(
        id: session.userId,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: session.createdAt.toIso8601String(),
        email: session.email,
      ),
      rememberMe: true,
      isRestoredOffline: true,
    );
  }

  @override
  AppAuthState build() {
    final authService = ref.watch(authServiceProvider);
    final initialRestored = ref.watch(initialRestoredSessionProvider);

    final subscription = authService.authStateChanges.listen((data) {
      // Ignore all auth events fired during sign-up flow.
      if (_isSigningUp) return;

      if (data.event == AuthChangeEvent.signedOut) {
        state = const AppAuthState();
        return;
      }

      if (data.session != null) {
        state = state.copyWith(
          session: () => data.session,
          user: () => data.session?.user,
          isLoading: false,
          errorMessage: () => null,
        );
      }
    });

    ref.onDispose(subscription.cancel);

    // If an online Supabase session is already present, use it.
    if (authService.currentUser != null) {
      return AppAuthState(
        session: authService.currentSession,
        user: authService.currentUser,
      );
    }

    // If an authenticated session with Remember Me was restored at startup, initialize with it.
    if (initialRestored != null && initialRestored.rememberMe) {
      return AppAuthState(
        user: User(
          id: initialRestored.userId,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: initialRestored.createdAt.toIso8601String(),
          email: initialRestored.email,
        ),
        rememberMe: true,
        isRestoredOffline: true,
      );
    }

    // Default initial unauthenticated state.
    return const AppAuthState();
  }

  /// Sign in with email and password.
  ///
  /// When [rememberMe] is true, the session is saved as restoration eligible across restarts.
  /// When [rememberMe] is false, the session is marked for current application session only.
  Future<bool> signIn(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: () => null,
      emailError: () => null,
      passwordError: () => null,
    );
    try {
      final authService = ref.read(authServiceProvider);
      final response = await authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = response.user ?? response.session?.user;
      if (user != null) {
        final localSessionService = ref.read(localSessionServiceProvider);
        await localSessionService.saveSession(
          userId: user.id,
          email: user.email ?? email.trim(),
          rememberMe: rememberMe,
        );
      }

      state = state.copyWith(
        session: () => response.session,
        user: () => user,
        isLoading: false,
        errorMessage: () => null,
        emailError: () => null,
        passwordError: () => null,
        isOfflineBypass: false,
        rememberMe: rememberMe,
        isRestoredOffline: false,
      );
      return true;
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();

      final isInvalidCredentials =
          lower.contains('invalid login credentials') ||
          lower.contains('invalid email or password') ||
          lower.contains('user not found') ||
          lower.contains('wrong password');

      if (isInvalidCredentials) {
        // Supabase does not distinguish which field is wrong for security reasons.
        // We use a simple heuristic: if the email looks valid, blame the password.
        final emailLooksValid =
            email.trim().contains('@') && email.trim().contains('.');
        if (emailLooksValid) {
          state = state.copyWith(
            isLoading: false,
            emailError: () => null,
            passwordError: () => 'Incorrect password. Please try again.',
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            emailError: () => 'No account found with this email address.',
            passwordError: () => null,
          );
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: () => _friendlySignInError(e.message),
        );
      }
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
  ///
  /// Returns true on success without logging in — caller switches to sign-in.
  Future<bool> signUp(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    _isSigningUp = true;
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Sign out immediately — we don't want auto-login after sign-up.
      await authService.signOut();
      _isSigningUp = false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => null,
        session: () => null,
        user: () => null,
      );
      return true;
    } on AuthException catch (e) {
      _isSigningUp = false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => _friendlySignUpError(e.message),
      );
      return false;
    } catch (e) {
      _isSigningUp = false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  /// Sign out current user from this device.
  ///
  /// Clears local session restoration state and signs out this device.
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      final localSessionService = ref.read(localSessionServiceProvider);
      await localSessionService.clearSession();
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      state = const AppAuthState();
    } catch (e) {
      state = const AppAuthState();
    }
  }

  /// Clear any error message.
  void clearError() {
    if (state.errorMessage != null ||
        state.emailError != null ||
        state.passwordError != null) {
      state = state.copyWith(
        errorMessage: () => null,
        emailError: () => null,
        passwordError: () => null,
      );
    }
  }

  /// Maps raw Supabase sign-in error messages to user-friendly text.
  String _friendlySignInError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid email or password') ||
        lower.contains('wrong password') ||
        lower.contains('user not found')) {
      return 'Incorrect email or password. Please check your details and try again.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Your email is not confirmed yet. Please check your inbox and confirm your address before signing in.';
    }
    if (lower.contains('too many requests') || lower.contains('rate limit')) {
      return 'Too many failed attempts. Please wait a moment before trying again.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    return raw;
  }

  /// Maps raw Supabase sign-up error messages to user-friendly text.
  String _friendlySignUpError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('already registered') ||
        lower.contains('already exists') ||
        lower.contains('user already')) {
      return 'An account with this email already exists. Please sign in instead.';
    }
    if (lower.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    if (lower.contains('password')) {
      return 'Password must be at least 6 characters.';
    }
    return raw;
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
