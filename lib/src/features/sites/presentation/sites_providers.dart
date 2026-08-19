import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_provider.dart';
import '../data/sites_repository.dart';
import '../domain/site_model.dart';

final sitesRepositoryProvider = Provider<SitesRepository>((ref) {
  return SitesRepository(ref.watch(appDatabaseProvider), const Uuid());
});

final sitesSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final sitesStatusFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final sitesProvider = StreamProvider.autoDispose<List<SiteModel>>((ref) {
  final searchQuery = ref.watch(sitesSearchProvider);
  final statusFilter = ref.watch(sitesStatusFilterProvider);
  return ref
      .watch(sitesRepositoryProvider)
      .watchSites(searchQuery: searchQuery, statusFilter: statusFilter);
});
