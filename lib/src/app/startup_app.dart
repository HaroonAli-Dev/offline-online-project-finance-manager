import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/supabase_config.dart';
import '../core/database/app_database.dart';
import '../core/providers/database_provider.dart';
import '../core/sync/sync_trigger_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/services/local_session_service.dart';
import 'app.dart';

class StartupApp extends StatelessWidget {
  const StartupApp({
    super.key,
    required this.databaseFuture,
    this.readyChild,
    this.localSessionService,
  });

  final Future<AppDatabase> databaseFuture;
  final Widget? readyChild;
  final LocalSessionService? localSessionService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance & Construction Manager',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: _StartupGate(
        databaseFuture: databaseFuture,
        readyChild: readyChild,
        localSessionService: localSessionService,
      ),
    );
  }
}

class _StartupResult {
  const _StartupResult({
    required this.database,
    this.restoredSession,
  });

  final AppDatabase database;
  final LocalSessionData? restoredSession;
}

class _StartupGate extends StatefulWidget {
  const _StartupGate({
    required this.databaseFuture,
    this.readyChild,
    this.localSessionService,
  });

  final Future<AppDatabase> databaseFuture;
  final Widget? readyChild;
  final LocalSessionService? localSessionService;

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> with WidgetsBindingObserver {
  late Future<_StartupResult> _startupFuture;
  late final LocalSessionService _sessionService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionService =
        widget.localSessionService ?? LocalSessionService.instance;
    _startupFuture = _initStartup();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app is closed, detached, or hidden:
    // If Remember Me was disabled, clear the session locally.
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _sessionService.isRememberMeEnabled().then((enabled) {
        if (!enabled) {
          _sessionService.clearSession();
          if (SupabaseConfig.isInitialized) {
            try {
              SupabaseConfig.client.auth.signOut(scope: SignOutScope.local);
            } catch (_) {}
          }
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<_StartupResult> _initStartup() async {
    final database = await widget.databaseFuture;

    // Load local session state
    final rawSession = await _sessionService.getRawSession();

    if (rawSession == null) {
      // No local authenticated user -> Show Login Page
      return _StartupResult(database: database, restoredSession: null);
    }

    if (!rawSession.rememberMe) {
      // Remember Me disabled -> Clear session -> Show Login Page
      await _sessionService.clearSession();
      if (SupabaseConfig.isInitialized) {
        try {
          await SupabaseConfig.client.auth.signOut(scope: SignOutScope.local);
        } catch (_) {}
      }
      return _StartupResult(database: database, restoredSession: null);
    }

    // Remember Me enabled -> Restore local authenticated state
    final restored = await _sessionService.loadRestorationSession();
    return _StartupResult(database: database, restoredSession: restored);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupResult>(
      future: _startupFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupError(error: snapshot.error);
        }

        final result = snapshot.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: result == null
              ? const _StartupSplash(key: ValueKey('splash'))
              : ProviderScope(
                  key: const ValueKey('application'),
                  overrides: [
                    appDatabaseProvider.overrideWithValue(result.database),
                    localSessionServiceProvider.overrideWithValue(_sessionService),
                    if (result.restoredSession != null)
                      initialRestoredSessionProvider.overrideWithValue(
                        result.restoredSession,
                      ),
                  ],
                  child: SyncTriggerHost(
                    child: widget.readyChild ?? const _AuthGate(),
                  ),
                ),
        );
      },
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    return isAuthenticated ? const MainNavigationShell() : const LoginScreen();
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoSize = (constraints.biggest.shortestSide * 0.42).clamp(
              140.0,
              280.0,
            );
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.94, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) => Opacity(
                opacity: ((scale - 0.94) / 0.06).clamp(0.0, 1.0),
                child: Transform.scale(scale: scale, child: child),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    appLogoAsset,
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Finance & Construction Manager',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              const Text(
                'The application could not start.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error?.toString() ?? 'Unknown startup error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
