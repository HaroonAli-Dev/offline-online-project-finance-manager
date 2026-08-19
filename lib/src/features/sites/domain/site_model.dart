class SiteModel {
  const SiteModel({
    required this.id,
    required this.name,
    this.roadInfo,
    this.latitude,
    this.longitude,
    required this.status,
    this.notes,
  });

  final String id;
  final String name;
  final String? roadInfo;
  final double? latitude;
  final double? longitude;
  final String status;
  final String? notes;

  String get coordinatesDisplay {
    if (latitude == null || longitude == null) return 'No coordinates';
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }
}
