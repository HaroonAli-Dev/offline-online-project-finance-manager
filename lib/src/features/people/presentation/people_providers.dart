import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_provider.dart';
import '../data/people_repository.dart';
import '../domain/person_summary.dart';
import '../domain/role_definition.dart';

final peopleRepositoryProvider = Provider<PeopleRepository>((ref) {
  return PeopleRepository(ref.watch(appDatabaseProvider), const Uuid());
});

final peopleSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final peopleRoleFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final peopleIncludeInactiveProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

final peopleProvider = StreamProvider.autoDispose<List<PersonSummary>>((ref) {
  final searchQuery = ref.watch(peopleSearchProvider);
  final roleCode = ref.watch(peopleRoleFilterProvider);
  final includeInactive = ref.watch(peopleIncludeInactiveProvider);
  return ref
      .watch(peopleRepositoryProvider)
      .watchPeople(
        searchQuery: searchQuery,
        roleCode: roleCode,
        includeInactive: includeInactive,
      );
});

final rolesProvider = StreamProvider.autoDispose<List<RoleDefinition>>((ref) {
  return ref.watch(peopleRepositoryProvider).watchRoles();
});
