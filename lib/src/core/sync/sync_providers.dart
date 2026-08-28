import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../providers/database_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/documents/data/attachment_storage_service.dart';
import 'sync_engine.dart';

/// Provider for [RemoteSyncClient] using active Supabase instance when initialized.
final remoteSyncClientProvider = Provider<RemoteSyncClient?>((ref) {
  if (!SupabaseConfig.isInitialized) return null;
  try {
    return SupabaseRemoteSyncClient(Supabase.instance.client);
  } catch (_) {
    return null;
  }
});

/// Provider for [AttachmentStorageClient] using active Supabase instance when initialized.
final attachmentStorageClientProvider = Provider<AttachmentStorageClient?>((
  ref,
) {
  if (!SupabaseConfig.isInitialized) return null;
  try {
    return SupabaseAttachmentStorageClient(Supabase.instance.client);
  } catch (_) {
    return null;
  }
});

/// Provider for [SyncEngine] singleton bound to [AppDatabase].
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final remoteClient = ref.watch(remoteSyncClientProvider);
  final storageClient = ref.watch(attachmentStorageClientProvider);

  final engine = SyncEngine(
    database: database,
    remoteClient: remoteClient,
    storageClient: storageClient,
  );

  ref.onDispose(engine.dispose);
  return engine;
});

/// Stream provider for listening to sync engine status updates in the UI.
final syncStatusStreamProvider = StreamProvider<SyncStatusSnapshot>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.statusStream;
});

/// Notifier for triggering manual or automated sync runs and maintaining [SyncStatusSnapshot].
class SyncNotifier extends Notifier<SyncStatusSnapshot> {
  Future<bool>? _inFlight;

  @override
  SyncStatusSnapshot build() {
    final engine = ref.watch(syncEngineProvider);
    final subscription = engine.statusStream.listen((status) {
      state = status;
    });
    ref.onDispose(subscription.cancel);
    return engine.status;
  }

  /// Triggers a synchronization cycle for the currently authenticated user.
  Future<bool> synchronize() async {
    final existing = _inFlight;
    if (existing != null) return existing;

    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated || authState.isOfflineBypass) {
      return false;
    }

    final userId = authState.user?.id;
    if (userId == null) return false;

    final engine = ref.read(syncEngineProvider);
    final future = engine.sync(userId: userId);
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }
}

/// Provider exposing [SyncNotifier] for user-facing sync triggers.
final syncControllerProvider =
    NotifierProvider<SyncNotifier, SyncStatusSnapshot>(() {
      return SyncNotifier();
    });
