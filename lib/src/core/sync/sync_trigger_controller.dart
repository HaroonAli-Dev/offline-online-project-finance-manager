import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'sync_providers.dart';

class SyncTriggerController {
  SyncTriggerController(
    ProviderContainer container, {
    ConnectivitySource? connectivity,
    bool Function()? configuredCheck,
    bool Function()? authenticatedCheck,
    String? Function()? userIdProvider,
    Future<bool> Function()? syncCallback,
  }) : _connectivity = connectivity ?? ConnectivitySourceAdapter(),
       _configuredCheck =
           configuredCheck ?? (() => SupabaseConfig.isInitialized),
       _authenticatedCheck =
           authenticatedCheck ??
           (() {
             final state = container.read(authStateProvider);
             return state.isAuthenticated && !state.isOfflineBypass;
           }),
       _userIdProvider =
           userIdProvider ?? (() => container.read(authStateProvider).user?.id),
       _syncCallback =
           syncCallback ??
           (() =>
               container.read(syncControllerProvider.notifier).synchronize());

  final ConnectivitySource _connectivity;
  final bool Function() _configuredCheck;
  final bool Function() _authenticatedCheck;
  final String? Function() _userIdProvider;
  final Future<bool> Function() _syncCallback;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Future<bool>? _inFlight;
  bool _wasOnline = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_disposed || _connectivitySubscription != null) return;
    try {
      _wasOnline = _isOnline(await _connectivity.checkConnectivity());
    } catch (_) {
      _wasOnline = false;
    }
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivity,
    );
    if (_wasOnline) unawaited(trigger(SyncTrigger.startup));
  }

  void _handleConnectivity(List<ConnectivityResult> result) {
    final isOnline = _isOnline(result);
    final wasOffline = !_wasOnline;
    _wasOnline = isOnline;
    if (isOnline && wasOffline) {
      unawaited(trigger(SyncTrigger.connectivityRestored));
    }
  }

  Future<bool> trigger(SyncTrigger reason) {
    if (_disposed || !_configuredCheck() || !_wasOnline) {
      return Future.value(false);
    }
    final existing = _inFlight;
    if (existing != null) return existing;

    final future = _synchronizeIfEligible();
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  Future<bool> _synchronizeIfEligible() async {
    if (!_authenticatedCheck() || _userIdProvider() == null) return false;
    return _syncCallback();
  }

  Future<void> dispose() async {
    _disposed = true;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}

enum SyncTrigger { startup, connectivityRestored, appResumed }

class SyncTriggerHost extends ConsumerStatefulWidget {
  const SyncTriggerHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncTriggerHost> createState() => _SyncTriggerHostState();
}

class _SyncTriggerHostState extends ConsumerState<SyncTriggerHost>
    with WidgetsBindingObserver {
  SyncTriggerController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _controller = SyncTriggerController(ProviderScope.containerOf(context));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _controller;
      if (controller != null) unawaited(controller.start());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final controller = _controller;
      if (controller != null) {
        unawaited(controller.trigger(SyncTrigger.appResumed));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

abstract class ConnectivitySource {
  Stream<List<ConnectivityResult>> get onConnectivityChanged;
  Future<List<ConnectivityResult>> checkConnectivity();
}

class ConnectivitySourceAdapter implements ConnectivitySource {
  ConnectivitySourceAdapter({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() =>
      _connectivity.checkConnectivity();
}
