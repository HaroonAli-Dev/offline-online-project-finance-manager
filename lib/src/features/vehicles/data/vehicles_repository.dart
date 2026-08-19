import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/vehicle_model.dart';

class VehiclesRepository {
  VehiclesRepository(this._database, this._uuid);

  final AppDatabase _database;
  final Uuid _uuid;

  Stream<List<VehicleModel>> watchVehicles({
    String searchQuery = '',
    String? statusFilter,
    String? siteFilter,
  }) {
    final cleanQuery = searchQuery.trim();
    final cleanStatus = statusFilter?.trim() ?? '';
    final cleanSite = siteFilter?.trim() ?? '';

    const querySql = '''
      SELECT
        v.id,
        v.vehicle_number,
        v.make_model,
        v.vehicle_type,
        v.assigned_site_id,
        st.name AS assigned_site_name,
        v.assigned_driver_id,
        p.full_name AS assigned_driver_name,
        v.status,
        v.remarks
      FROM vehicles v
      LEFT JOIN sites st ON st.id = v.assigned_site_id AND st.deleted_at IS NULL
      LEFT JOIN people p ON p.id = v.assigned_driver_id AND p.deleted_at IS NULL
      WHERE v.deleted_at IS NULL
        AND (? = '' OR v.status = ?)
        AND (? = '' OR v.assigned_site_id = ?)
        AND (
          ? = ''
          OR LOWER(v.vehicle_number) LIKE LOWER(?)
          OR LOWER(v.make_model) LIKE LOWER(?)
        )
      ORDER BY v.vehicle_number COLLATE NOCASE
    ''';
    final pattern = '%$cleanQuery%';

    return _database
        .customSelect(
          querySql,
          variables: [
            Variable.withString(cleanStatus),
            Variable.withString(cleanStatus),
            Variable.withString(cleanSite),
            Variable.withString(cleanSite),
            Variable.withString(cleanQuery),
            Variable.withString(pattern),
            Variable.withString(pattern),
          ],
          readsFrom: {_database.vehicles, _database.sites, _database.people},
        )
        .watch()
        .map((rows) => rows.map(_vehicleFromRow).toList());
  }

  Stream<List<VehicleLogModel>> watchVehicleLogs(String vehicleId) {
    const querySql = '''
      SELECT
        vl.id,
        vl.vehicle_id,
        vl.log_date,
        vl.log_type,
        vl.amount,
        vl.quantity_liters,
        vl.driver_id,
        p.full_name AS driver_name,
        vl.site_id,
        st.name AS site_name,
        vl.description,
        vl.odometer_reading
      FROM vehicle_logs vl
      LEFT JOIN people p ON p.id = vl.driver_id AND p.deleted_at IS NULL
      LEFT JOIN sites st ON st.id = vl.site_id AND st.deleted_at IS NULL
      WHERE vl.deleted_at IS NULL
        AND vl.vehicle_id = ?
      ORDER BY vl.log_date DESC, vl.created_at DESC
    ''';

    return _database
        .customSelect(
          querySql,
          variables: [Variable.withString(vehicleId)],
          readsFrom: {_database.vehicleLogs, _database.people, _database.sites},
        )
        .watch()
        .map((rows) => rows.map(_logFromRow).toList());
  }

  Future<void> createVehicle({
    required String vehicleNumber,
    required String makeModel,
    String vehicleType = 'truck',
    String? assignedSiteId,
    String? assignedDriverId,
    String status = 'active',
    String? remarks,
  }) async {
    final now = DateTime.now().toUtc();
    final vehicleId = _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.vehicles)
          .insert(
            VehiclesCompanion.insert(
              id: vehicleId,
              vehicleNumber: vehicleNumber.trim(),
              makeModel: makeModel.trim(),
              vehicleType: Value(
                vehicleType.trim().isEmpty ? 'truck' : vehicleType.trim(),
              ),
              assignedSiteId: Value(_cleanOptional(assignedSiteId)),
              assignedDriverId: Value(_cleanOptional(assignedDriverId)),
              status: Value(status.trim().isEmpty ? 'active' : status.trim()),
              remarks: Value(_cleanOptional(remarks)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueueChange('vehicle', vehicleId, 'create', now);
    });
  }

  Future<void> updateVehicle({
    required String id,
    required String vehicleNumber,
    required String makeModel,
    required String vehicleType,
    String? assignedSiteId,
    String? assignedDriverId,
    required String status,
    String? remarks,
  }) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.vehicles,
      )..where((v) => v.id.equals(id))).write(
        VehiclesCompanion(
          vehicleNumber: Value(vehicleNumber.trim()),
          makeModel: Value(makeModel.trim()),
          vehicleType: Value(vehicleType.trim()),
          assignedSiteId: Value(_cleanOptional(assignedSiteId)),
          assignedDriverId: Value(_cleanOptional(assignedDriverId)),
          status: Value(status.trim()),
          remarks: Value(_cleanOptional(remarks)),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pending.databaseValue),
        ),
      );
      await _enqueueChange('vehicle', id, 'update', now);
    });
  }

  Future<void> deleteVehicle(String id) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.vehicles,
      )..where((v) => v.id.equals(id))).write(
        VehiclesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pendingDelete.databaseValue),
        ),
      );
      await _enqueueChange('vehicle', id, 'delete', now);
    });
  }

  Future<void> addVehicleLog({
    required String vehicleId,
    required DateTime logDate,
    required String logType,
    required double amount,
    double? quantityLiters,
    String? driverId,
    String? siteId,
    required String description,
    double? odometerReading,
  }) async {
    final now = DateTime.now().toUtc();
    final logId = _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.vehicleLogs)
          .insert(
            VehicleLogsCompanion.insert(
              id: logId,
              vehicleId: vehicleId,
              logDate: logDate.toUtc(),
              logType: logType.trim(),
              amount: Value(amount < 0 ? 0 : (amount * 100).round()),
              quantityLiters: Value(quantityLiters),
              driverId: Value(_cleanOptional(driverId)),
              siteId: Value(_cleanOptional(siteId)),
              description: description.trim(),
              odometerReading: Value(odometerReading),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueueChange('vehicle_log', logId, 'create', now);
    });
  }

  Future<void> deleteVehicleLog(String logId) async {
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      await (_database.update(
        _database.vehicleLogs,
      )..where((vl) => vl.id.equals(logId))).write(
        VehicleLogsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: Value(SyncStatus.pendingDelete.databaseValue),
        ),
      );
      await _enqueueChange('vehicle_log', logId, 'delete', now);
    });
  }

  Future<void> _enqueueChange(
    String entityType,
    String entityId,
    String operation,
    DateTime now,
  ) async {
    final existing =
        await (_database.select(_database.syncOutbox)..where(
              (entry) =>
                  entry.entityType.equals(entityType) &
                  entry.entityId.equals(entityId) &
                  entry.operation.equals(operation),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (_database.update(
        _database.syncOutbox,
      )..where((entry) => entry.id.equals(existing.id))).write(
        SyncOutboxCompanion(
          updatedAt: Value(now),
          attemptCount: const Value(0),
          nextAttemptAt: const Value(null),
          lastError: const Value(null),
        ),
      );
    } else {
      await _database
          .into(_database.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: _uuid.v4(),
              entityType: entityType,
              entityId: entityId,
              operation: operation,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
  }

  VehicleModel _vehicleFromRow(QueryRow row) {
    return VehicleModel(
      id: row.read<String>('id'),
      vehicleNumber: row.read<String>('vehicle_number'),
      makeModel: row.read<String>('make_model'),
      vehicleType: row.read<String>('vehicle_type'),
      assignedSiteId: row.readNullable<String>('assigned_site_id'),
      assignedSiteName: row.readNullable<String>('assigned_site_name'),
      assignedDriverId: row.readNullable<String>('assigned_driver_id'),
      assignedDriverName: row.readNullable<String>('assigned_driver_name'),
      status: row.read<String>('status'),
      remarks: row.readNullable<String>('remarks'),
    );
  }

  VehicleLogModel _logFromRow(QueryRow row) {
    return VehicleLogModel(
      id: row.read<String>('id'),
      vehicleId: row.read<String>('vehicle_id'),
      logDate: row.read<DateTime>('log_date'),
      logType: row.read<String>('log_type'),
      amount: (row.read<int>('amount')) / 100.0,
      quantityLiters: row.readNullable<double>('quantity_liters'),
      driverId: row.readNullable<String>('driver_id'),
      driverName: row.readNullable<String>('driver_name'),
      siteId: row.readNullable<String>('site_id'),
      siteName: row.readNullable<String>('site_name'),
      description: row.read<String>('description'),
      odometerReading: row.readNullable<double>('odometer_reading'),
    );
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
