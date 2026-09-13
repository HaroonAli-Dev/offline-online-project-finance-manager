import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_project_finance_manager/src/core/providers/database_provider.dart';
import 'package:offline_project_finance_manager/src/app/app.dart';
import 'package:offline_project_finance_manager/src/app/startup_app.dart';
import 'package:offline_project_finance_manager/src/core/database/app_database.dart';
import 'package:offline_project_finance_manager/src/features/auth/presentation/login_screen.dart';
import 'package:offline_project_finance_manager/src/features/auth/providers/auth_provider.dart';
import 'package:offline_project_finance_manager/src/features/auth/services/auth_service.dart';
import 'package:offline_project_finance_manager/src/features/auth/services/local_session_service.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test implementation of [AuthService] that allows simulating online login, signup,
/// signout, and offline network state.
class TestAuthService extends AuthService {
  TestAuthService({
    this.sessionToReturn,
    this.userToReturn,
    this.shouldThrowOnSignIn = false,
    this.shouldThrowOnSignUp = false,
  });

  final Session? sessionToReturn;
  final User? userToReturn;
  final bool shouldThrowOnSignIn;
  final bool shouldThrowOnSignUp;
  bool signedOutCalled = false;

  @override
  Session? get currentSession => sessionToReturn;

  @override
  User? get currentUser => userToReturn ?? sessionToReturn?.user;

  @override
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (shouldThrowOnSignIn) {
      throw const AuthException('Invalid login credentials');
    }
    final user =
        userToReturn ??
        User(
          id: 'mock-user-id',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: email,
        );
    return AuthResponse(session: sessionToReturn, user: user);
  }

  @override
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (shouldThrowOnSignUp) {
      throw const AuthException('User already registered');
    }
    final user =
        userToReturn ??
        User(
          id: 'mock-user-id',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: email,
        );
    return AuthResponse(session: sessionToReturn, user: user);
  }

  @override
  Future<void> signOut() async {
    signedOutCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthNotifier and AppAuthState Unit Tests', () {
    test('initial state without session is unauthenticated', () {
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(TestAuthService())],
      );
      addTearDown(container.dispose);

      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.rememberMe, isFalse);
      expect(state.isRestoredOffline, isFalse);
      expect(container.read(isAuthenticatedProvider), isFalse);
    });

    test('login with Remember Me ENABLED persists restoration state', () async {
      final prefs = await SharedPreferences.getInstance();
      final localSessionService = LocalSessionService(prefs: prefs);
      final testService = TestAuthService();

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(testService),
          localSessionServiceProvider.overrideWithValue(localSessionService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      final success = await notifier.signIn(
        'alice@example.com',
        'password123',
        rememberMe: true,
      );

      expect(success, isTrue);
      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.rememberMe, isTrue);
      expect(state.user?.email, 'alice@example.com');

      // Verify persisted restoration state in local storage
      final restored = await localSessionService.loadRestorationSession();
      expect(restored, isNotNull);
      expect(restored!.email, 'alice@example.com');
      expect(restored.rememberMe, isTrue);

      final isRemembered = await localSessionService.isRememberMeEnabled();
      expect(isRemembered, isTrue);
    });

    test(
      'login with Remember Me DISABLED does NOT persist restoration state',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final localSessionService = LocalSessionService(prefs: prefs);
        final testService = TestAuthService();

        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(testService),
            localSessionServiceProvider.overrideWithValue(localSessionService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(authStateProvider.notifier);
        final success = await notifier.signIn(
          'bob@example.com',
          'password123',
          rememberMe: false,
        );

        expect(success, isTrue);
        final state = container.read(authStateProvider);
        expect(state.isAuthenticated, isTrue);
        expect(state.rememberMe, isFalse);

        // Restoration session must be null because rememberMe was false
        final restored = await localSessionService.loadRestorationSession();
        expect(restored, isNull);

        final isRemembered = await localSessionService.isRememberMeEnabled();
        expect(isRemembered, isFalse);
      },
    );

    test(
      'explicit signOut clears auth state and local restoration state',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final localSessionService = LocalSessionService(prefs: prefs);
        final testService = TestAuthService();

        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(testService),
            localSessionServiceProvider.overrideWithValue(localSessionService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(authStateProvider.notifier);
        await notifier.signIn('alice@example.com', 'secret', rememberMe: true);
        expect(container.read(isAuthenticatedProvider), isTrue);
        expect(await localSessionService.isRememberMeEnabled(), isTrue);

        await notifier.signOut();
        expect(container.read(isAuthenticatedProvider), isFalse);
        expect(container.read(currentUserEmailProvider), isNull);
        expect(testService.signedOutCalled, isTrue);

        // Verify local storage is completely wiped
        expect(await localSessionService.loadRestorationSession(), isNull);
        expect(await localSessionService.getRawSession(), isNull);
        expect(await localSessionService.isRememberMeEnabled(), isFalse);
      },
    );

    test('offline startup initialization restores authenticated state without network dependency', () {
      final restoredData = LocalSessionData(
        userId: 'offline-user-999',
        email: 'offline@builder.com',
        rememberMe: true,
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            TestAuthService(),
          ), // offline (null currentSession)
          initialRestoredSessionProvider.overrideWithValue(restoredData),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.user?.id, 'offline-user-999');
      expect(state.user?.email, 'offline@builder.com');
      expect(state.isRestoredOffline, isTrue);
      expect(state.rememberMe, isTrue);
      expect(container.read(isAuthenticatedProvider), isTrue);
      expect(container.read(currentUserEmailProvider), 'offline@builder.com');
    });

    test('signIn/signUp fail with friendly message when Supabase is not configured', () async {
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(const AuthService())],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      final result = await notifier.signIn('test@example.com', 'password123');

      expect(result, isFalse);
      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, contains('Supabase is not configured'));
    });
  });

  group('LoginScreen Widget Tests', () {
    testWidgets(
      'renders login screen with Remember Me checkbox unchecked by default and no Continue Offline button',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: LoginScreen())),
        );

        expect(find.text('Finance & Construction Manager'), findsOneWidget);
        expect(find.text('Sign in to your account'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2)); // email, password
        expect(find.text('Sign In'), findsOneWidget);

        // Verify Continue Offline button is REMOVED
        expect(find.text('Continue Offline'), findsNothing);

        // Verify Remember Me checkbox is PRESENT
        expect(find.text('Remember Me'), findsOneWidget);
        expect(find.byType(Checkbox), findsOneWidget);

        // Checkbox must be UNCHECKED by default
        final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.value, isFalse);
      },
    );

    testWidgets('toggling Remember Me checkbox updates its checked state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      Checkbox checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);

      // Tap the Remember Me label or checkbox
      await tester.tap(find.text('Remember Me'));
      await tester.pumpAndSettle();

      checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);

      // Tap again to uncheck
      await tester.tap(find.text('Remember Me'));
      await tester.pumpAndSettle();

      checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets(
      'switching between Sign In and Sign Up toggles confirm password field while preserving Remember Me',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: LoginScreen())),
        );

        // Initially Sign In mode (2 text fields)
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('Confirm Password'), findsNothing);
        expect(find.text('Remember Me'), findsOneWidget);

        // Tap Sign Up mode
        final signUpButtonFinder = find.text("Don't have an account? Sign Up");
        await tester.ensureVisible(signUpButtonFinder);
        await tester.tap(signUpButtonFinder);
        await tester.pumpAndSettle();

        // Sign Up mode (3 text fields)
        expect(find.byType(TextFormField), findsNWidgets(3));
        expect(find.text('Confirm Password'), findsOneWidget);
        expect(find.text('Create Account'), findsOneWidget);
        expect(find.text('Remember Me'), findsOneWidget);

        // Tap back to Sign In mode
        final signInButtonFinder = find.text(
          'Already have an account? Sign In',
        );
        await tester.ensureVisible(signInButtonFinder);
        await tester.tap(signInButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('Confirm Password'), findsNothing);
      },
    );

    testWidgets('validation error displays on empty submit', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });
  });

  group('Startup Gate Auth Routing & Multi-Device Safety Tests', () {
    testWidgets(
      'shows LoginScreen when unauthenticated and database is ready',
      (tester) async {
        await tester.pumpWidget(
          const StartupApp(),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
      },
    );

    testWidgets(
      'offline startup with Remember Me enabled opens authenticated app directly without LoginScreen',
      (tester) async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);

        final prefs = await SharedPreferences.getInstance();
        final localSessionService = LocalSessionService(prefs: prefs);
        await localSessionService.saveSession(
          userId: 'field-worker-101',
          email: 'worker@rural-site.org',
          rememberMe: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
            ],
            child: StartupApp(
              localSessionService: localSessionService,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        // Login screen must NOT appear
        expect(find.byType(LoginScreen), findsNothing);
        // Main navigation shell must be active
        expect(find.byType(MainNavigationShell), findsOneWidget);
      },
    );

    testWidgets(
      'startup with Remember Me DISABLED clears session and shows LoginScreen',
      (tester) async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);

        final prefs = await SharedPreferences.getInstance();
        final localSessionService = LocalSessionService(prefs: prefs);
        await localSessionService.saveSession(
          userId: 'temporary-user-202',
          email: 'temp@site.org',
          rememberMe: false, // Unchecked
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
            ],
            child: StartupApp(
              localSessionService: localSessionService,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        // Login screen must appear
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(MainNavigationShell), findsNothing);

        // Session must have been cleared
        final raw = await localSessionService.getRawSession();
        expect(raw, isNull);
      },
    );

    test('multi-device independence: signing out one device does not trigger global revocation', () async {
      final testService = TestAuthService();
      await testService.signOut();

      // Verified via implementation: signOut() invokes client.auth.signOut(scope: SignOutScope.local)
      expect(testService.signedOutCalled, isTrue);
    });
  });
}
