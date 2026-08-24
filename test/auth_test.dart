import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/app/startup_app.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';
import 'package:offline_finance_management_app/src/features/auth/presentation/login_screen.dart';
import 'package:offline_finance_management_app/src/features/auth/providers/auth_provider.dart';
import 'package:offline_finance_management_app/src/features/auth/services/auth_service.dart';
import 'package:drift/native.dart';

class MockAuthService extends AuthService {
  const MockAuthService();
}

void main() {
  group('AuthNotifier and AppAuthState', () {
    test('initial state without session is unauthenticated', () {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(const MockAuthService()),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.isOfflineBypass, isFalse);
      expect(container.read(isAuthenticatedProvider), isFalse);
    });

    test('continueOffline sets isOfflineBypass and isAuthenticated to true', () {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(const MockAuthService()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      notifier.continueOffline();

      final state = container.read(authStateProvider);
      expect(state.isOfflineBypass, isTrue);
      expect(state.isAuthenticated, isTrue);
      expect(container.read(isAuthenticatedProvider), isTrue);
      expect(container.read(currentUserEmailProvider), 'Offline Mode');
    });

    test('signOut resets auth state cleanly', () async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(const MockAuthService()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      notifier.continueOffline();
      expect(container.read(isAuthenticatedProvider), isTrue);

      await notifier.signOut();
      expect(container.read(isAuthenticatedProvider), isFalse);
      expect(container.read(currentUserEmailProvider), isNull);
    });

    test('signIn/signUp fail with friendly message when Supabase is not configured', () async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(const MockAuthService()),
        ],
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
    testWidgets('renders login screen with inputs, buttons, and offline mode option', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Finance & Construction Manager'), findsOneWidget);
      expect(find.text('Sign in to your account'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // email, password
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Continue Offline'), findsOneWidget);
      expect(find.text("Don't have an account? Sign Up"), findsOneWidget);
    });

    testWidgets('switching between Sign In and Sign Up toggles confirm password field', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Initially Sign In mode (2 text fields)
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Confirm Password'), findsNothing);

      // Tap Sign Up mode
      final signUpButtonFinder = find.text("Don't have an account? Sign Up");
      await tester.ensureVisible(signUpButtonFinder);
      await tester.tap(signUpButtonFinder);
      await tester.pumpAndSettle();

      // Sign Up mode (3 text fields)
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);

      // Tap back to Sign In mode
      final signInButtonFinder = find.text('Already have an account? Sign In');
      await tester.ensureVisible(signInButtonFinder);
      await tester.tap(signInButtonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Confirm Password'), findsNothing);
    });

    testWidgets('tapping Continue Offline triggers offline bypass', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(const MockAuthService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(container.read(isAuthenticatedProvider), isFalse);
      final continueOfflineFinder = find.text('Continue Offline');
      await tester.ensureVisible(continueOfflineFinder);
      await tester.tap(continueOfflineFinder);
      await tester.pumpAndSettle();

      expect(container.read(isAuthenticatedProvider), isTrue);
    });

    testWidgets('validation error displays on empty submit', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });
  });

  group('Startup Gate Auth Routing Tests', () {
    testWidgets('shows LoginScreen when unauthenticated and database is ready', (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await tester.pumpWidget(
        StartupApp(
          databaseFuture: Future.value(database),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });
  });
}
