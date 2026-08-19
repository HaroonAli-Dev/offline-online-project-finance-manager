import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_provider.dart';
import '../data/schemes_repository.dart';
import '../domain/scheme_model.dart';

final schemesRepositoryProvider = Provider<SchemesRepository>((ref) {
  return SchemesRepository(ref.watch(appDatabaseProvider), const Uuid());
});

final schemesSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final schemesSiteFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final schemesEngineerFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final schemesStatusFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final schemesProvider = StreamProvider.autoDispose<List<SchemeModel>>((ref) {
  final searchQuery = ref.watch(schemesSearchProvider);
  final siteFilter = ref.watch(schemesSiteFilterProvider);
  final engineerFilter = ref.watch(schemesEngineerFilterProvider);
  final statusFilter = ref.watch(schemesStatusFilterProvider);

  return ref
      .watch(schemesRepositoryProvider)
      .watchSchemes(
        searchQuery: searchQuery,
        siteFilter: siteFilter,
        engineerFilter: engineerFilter,
        statusFilter: statusFilter,
      );
});
