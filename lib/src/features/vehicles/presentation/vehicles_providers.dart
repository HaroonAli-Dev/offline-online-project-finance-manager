import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_provider.dart';
import '../data/vehicles_repository.dart';
import '../domain/vehicle_model.dart';

final vehiclesRepositoryProvider = Provider<VehiclesRepository>((ref) {
  return VehiclesRepository(ref.watch(appDatabaseProvider), const Uuid());
});

final vehiclesSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final vehiclesStatusFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final vehiclesProvider = StreamProvider.autoDispose<List<VehicleModel>>((ref) {
  final searchQuery = ref.watch(vehiclesSearchProvider);
  final statusFilter = ref.watch(vehiclesStatusFilterProvider);

  return ref
      .watch(vehiclesRepositoryProvider)
      .watchVehicles(searchQuery: searchQuery, statusFilter: statusFilter);
});

final vehicleLogsFamilyProvider = StreamProvider.autoDispose
    .family<List<VehicleLogModel>, String>((ref, vehicleId) {
      return ref.watch(vehiclesRepositoryProvider).watchVehicleLogs(vehicleId);
    });
