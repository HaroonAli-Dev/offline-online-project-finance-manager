import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/providers/database_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import 'app.dart';

class StartupApp extends StatelessWidget {
  const StartupApp({super.key, required this.databaseFuture, this.readyChild});

  final Future<AppDatabase> databaseFuture;
  final Widget? readyChild;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance & Construction Manager',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: _StartupGate(
        databaseFuture: databaseFuture,
        readyChild: readyChild,
      ),
    );
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate({required this.databaseFuture, this.readyChild});

  final Future<AppDatabase> databaseFuture;
  final Widget? readyChild;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDatabase>(
      future: databaseFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupError(error: snapshot.error);
        }

        final database = snapshot.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: database == null
              ? const _StartupSplash(key: ValueKey('splash'))
              : ProviderScope(
                  key: const ValueKey('application'),
                  overrides: [appDatabaseProvider.overrideWithValue(database)],
                  child: readyChild ?? const _AuthGate(),
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
