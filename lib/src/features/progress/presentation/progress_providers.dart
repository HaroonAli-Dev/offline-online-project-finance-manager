import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/async_value_extensions.dart';

import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_provider.dart';
import '../../schemes/domain/scheme_model.dart';
import '../../schemes/presentation/schemes_providers.dart';
import '../data/progress_repository.dart';
import '../domain/progress_model.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ref.watch(appDatabaseProvider), const Uuid());
});

final progressSearchQueryProvider = StateProvider<String>((ref) => '');
final progressStatusFilterProvider = StateProvider<String?>((ref) => null);
final progressSchemeFilterProvider = StateProvider<SchemeModel?>((ref) => null);

final progressListProvider = StreamProvider<List<ProgressModel>>((ref) {
  final repository = ref.watch(progressRepositoryProvider);
  final searchQuery = ref.watch(progressSearchQueryProvider);
  final statusFilter = ref.watch(progressStatusFilterProvider);
  final schemeFilter = ref.watch(progressSchemeFilterProvider);

  return repository.watchProgressUpdates(
    searchQuery: searchQuery,
    statusFilter: statusFilter,
    schemeIdFilter: schemeFilter?.id,
  );
});

final schemeProgressProvider =
    StreamProvider.family<List<ProgressModel>, String>((ref, schemeId) {
      return ref
          .watch(progressRepositoryProvider)
          .watchProgressByScheme(schemeId);
    });

/// All non-deleted schemes for the scheme filter dropdown.
final progressAllSchemesProvider = Provider<List<SchemeModel>>((ref) {
  return ref.watch(schemesProvider).valueOrNull ?? [];
});
