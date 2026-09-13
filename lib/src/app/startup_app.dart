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
    this.readyChild,
    this.localSessionService,
    this.database,
  });

  final Widget? readyChild;
  final LocalSessionService? localSessionService;
  final AppDatabase? database;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        if (localSessionService != null)
          localSessionServiceProvider.overrideWithValue(localSessionService!),
      ],
      child: MaterialApp(
        title: 'Offline Project Finance Management App',
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        home: _StartupGate(
          readyChild: readyChild,
          localSessionService: localSessionService,
          database: database,
        ),
      ),
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate({
    this.readyChild,
    this.localSessionService,
    this.database,
  });

  final Widget? readyChild;
  final LocalSessionService? localSessionService;
  final AppDatabase? database;

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate>
    with WidgetsBindingObserver {
  late final LocalSessionService _sessionService;
  late Future<LocalSessionData?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionService =
        widget.localSessionService ?? LocalSessionService.instance;
    _sessionFuture = _initSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _sessionService.isRememberMeEnabled().then((enabled) {
        if (!enabled) {
          _sessionService.clearSession();
          if (SupabaseConfig.isInitialized) {
            try {
              SupabaseConfig.client.auth.signOut();
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

  Future<LocalSessionData?> _initSession() async {
    final rawSession = await _sessionService.getRawSession();
    if (rawSession == null) return null;
    if (!rawSession.rememberMe) {
      await _sessionService.clearSession();
      if (SupabaseConfig.isInitialized) {
        try {
          await SupabaseConfig.client.auth.signOut();
        } catch (_) {}
      }
      return null;
    }
    return _sessionService.loadRestorationSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocalSessionData?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupError(error: snapshot.error);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupSplash(key: ValueKey('splash'));
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: ProviderScope(
            key: const ValueKey('application'),
            overrides: [
              localSessionServiceProvider.overrideWithValue(_sessionService),
              if (snapshot.data != null)
                initialRestoredSessionProvider.overrideWithValue(snapshot.data),
            ],
            child: _AuthGate(
              restoredSession: snapshot.data,
              readyChild: widget.readyChild,
              database: widget.database,
            ),
          ),
        );
      },
    );
  }
}

/// Opens a per-user database and provides it to the app.
/// Each user gets their own isolated SQLite file: finance_construction_(userId)
class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate({this.restoredSession, this.readyChild, this.database});

  final LocalSessionData? restoredSession;
  final Widget? readyChild;
  final AppDatabase? database;

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  AppDatabase? _database;
  String? _openedForUserId;
  bool _restoredSessionIsActive = true;

  @override
  void initState() {
    super.initState();
    final restoredSession = widget.restoredSession;
    if (restoredSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(authStateProvider.notifier)
              .restoreOfflineSession(restoredSession);
        }
      });
    }
  }

  Future<AppDatabase> _openDatabaseForUser(String userId) async {
    if (widget.database != null) return widget.database!;

    // Sanitize userId to be safe as a filename (keep alphanumeric + hyphens)
    final safeName = userId.replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '_');
    final db = AppDatabase(null, 'finance_construction_$safeName');
    await db.validateConnection();
    return db;
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    ref.listen<AppAuthState>(authStateProvider, (previous, next) {
      if (previous?.isAuthenticated == true && !next.isAuthenticated) {
        _restoredSessionIsActive = false;
      }
    });
    final isAuthenticated =
        authState.isAuthenticated &&
        (_restoredSessionIsActive || widget.restoredSession == null);

    if (!isAuthenticated) {
      // Close DB when user logs out
      if (_database != null) {
        _database!.close();
        _database = null;
        _openedForUserId = null;
      }
      return const LoginScreen();
    }

    final userId =
        authState.user?.id ?? widget.restoredSession?.userId ?? 'offline';

    // Already have the right DB open
    if (_database != null && _openedForUserId == userId) {
      return ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(_database!)],
        child: SyncTriggerHost(
          child: widget.readyChild ?? const MainNavigationShell(),
        ),
      );
    }

    // Need to open DB for this user
    return FutureBuilder<AppDatabase>(
      future: _openDatabaseForUser(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupError(error: snapshot.error);
        }
        if (!snapshot.hasData) {
          return const _StartupSplash(key: ValueKey('db-loading'));
        }

        // Cache it
        _database?.close();
        _database = snapshot.data!;
        _openedForUserId = userId;

        return ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(_database!)],
          child: SyncTriggerHost(
            child: widget.readyChild ?? const MainNavigationShell(),
          ),
        );
      },
    );
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
                    appLogoPngAsset,
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Offline Project Finance Management App',
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
