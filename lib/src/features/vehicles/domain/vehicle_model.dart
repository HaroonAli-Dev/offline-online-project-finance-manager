class VehicleModel {
  const VehicleModel({
    required this.id,
    required this.vehicleNumber,
    required this.makeModel,
    required this.vehicleType,
    this.assignedSiteId,
    this.assignedSiteName,
    this.assignedDriverId,
    this.assignedDriverName,
    required this.status,
    this.remarks,
  });

  final String id;
  final String vehicleNumber;
  final String makeModel;
  final String vehicleType;
  final String? assignedSiteId;
  final String? assignedSiteName;
  final String? assignedDriverId;
  final String? assignedDriverName;
  final String status;
  final String? remarks;

  String get typeDisplay {
    return switch (vehicleType) {
      'dumper' => 'Dumper',
      'excavator' => 'Excavator',
      'car' => 'Car / Jeep',
      'tractor' => 'Tractor',
      'other' => 'Other',
      _ => 'Truck',
    };
  }

  String get statusDisplay {
    return switch (status) {
      'under_maintenance' => 'Maintenance',
      'inactive' => 'Inactive',
      _ => 'Active',
    };
  }
}

class VehicleLogModel {
  const VehicleLogModel({
    required this.id,
    required this.vehicleId,
    required this.logDate,
    required this.logType, // fuel, maintenance, trip, expenditure
    required this.amount,
    this.quantityLiters,
    this.driverId,
    this.driverName,
    this.siteId,
    this.siteName,
    required this.description,
    this.odometerReading,
  });

  final String id;
  final String vehicleId;
  final DateTime logDate;
  final String logType;
  final double amount;
  final double? quantityLiters;
  final String? driverId;
  final String? driverName;
  final String? siteId;
  final String? siteName;
  final String description;
  final double? odometerReading;

  String get formattedAmount => 'Rs. ${amount.toStringAsFixed(2)}';

  String get logTypeDisplay {
    return switch (logType) {
      'fuel' => 'Fuel',
      'maintenance' => 'Maintenance',
      'trip' => 'Trip',
      _ => 'Expense',
    };
  }
}
