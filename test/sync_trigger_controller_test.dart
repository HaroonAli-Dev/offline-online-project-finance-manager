import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/sync/sync_trigger_controller.dart';

class _FakeConnectivity implements ConnectivitySource {
  final changes = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> initial = const [ConnectivityResult.none];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => initial;

  Future<void> dispose() => changes.close();
}

void main() {
  late ProviderContainer container;
  late _FakeConnectivity connectivity;
  late SyncTriggerController controller;

  setUp(() {
    container = ProviderContainer();
    connectivity = _FakeConnectivity();
  });

  tearDown(() async {
    await controller.dispose();
    await connectivity.dispose();
    container.dispose();
  });

  SyncTriggerController buildController({
    bool configured = true,
    bool authenticated = true,
    String? userId = 'user-1',
    required Future<bool> Function() sync,
  }) {
    return SyncTriggerController(
      container,
      connectivity: connectivity,
      configuredCheck: () => configured,
      authenticatedCheck: () => authenticated,
      userIdProvider: () => userId,
      syncCallback: sync,
    );
  }

  test('startup does not sync while offline', () async {
    var calls = 0;
    controller = buildController(sync: () async => calls++ == -1);
    await controller.start();
    expect(calls, 0);
  });

  test('connectivity restoration triggers one sync', () async {
    var calls = 0;
    controller = buildController(
      sync: () async {
        calls++;
        return true;
      },
    );
    await controller.start();
    connectivity.changes.add(const [ConnectivityResult.none]);
    connectivity.changes.add(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
  });

  test('startup triggers sync when online', () async {
    connectivity.initial = const [ConnectivityResult.wifi];
    var calls = 0;
    controller = buildController(
      sync: () async {
        calls++;
        return true;
      },
    );
    await controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
  });

  test('resume and connectivity events share one in-flight sync', () async {
    connectivity.initial = const [ConnectivityResult.wifi];
    final completer = Completer<bool>();
    var calls = 0;
    controller = buildController(
      sync: () {
        calls++;
        return completer.future;
      },
    );
    await controller.start();
    final first = controller.trigger(SyncTrigger.appResumed);
    connectivity.changes.add(const [ConnectivityResult.none]);
    connectivity.changes.add(const [ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    completer.complete(true);
    expect(await first, isTrue);
  });

  test('configuration and authentication gate automatic sync', () async {
    var calls = 0;
    controller = buildController(
      configured: false,
      sync: () async {
        calls++;
        return true;
      },
    );
    connectivity.initial = const [ConnectivityResult.wifi];
    await controller.start();
    await controller.trigger(SyncTrigger.appResumed);
    expect(calls, 0);

    controller = buildController(
      authenticated: false,
      sync: () async {
        calls++;
        return true;
      },
    );
    await controller.trigger(SyncTrigger.appResumed);
    expect(calls, 0);
  });

  test('a failed sync can be retried by a later restoration', () async {
    var calls = 0;
    controller = buildController(
      sync: () async {
        calls++;
        return false;
      },
    );
    await controller.start();
    connectivity.changes.add(const [ConnectivityResult.none]);
    connectivity.changes.add(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    connectivity.changes.add(const [ConnectivityResult.none]);
    connectivity.changes.add(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 2);
  });
}
