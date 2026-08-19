/// Domain model for a historical progress update record.
class ProgressModel {
  const ProgressModel({
    required this.id,
    required this.schemeId,
    required this.schemeName,
    this.siteId,
    this.siteName,
    required this.status,
    required this.progressPercentage,
    required this.date,
    this.incompleteReason,
    this.result,
    this.remarks,
  });

  final String id;
  final String schemeId;
  final String schemeName;
  final String? siteId;
  final String? siteName;

  /// 'initial', 'working', 'in_progress', 'completed', 'incomplete'
  final String status;

  /// 0.0 - 100.0
  final double progressPercentage;

  final DateTime date;

  final String? incompleteReason;
  final String? result;
  final String? remarks;

  String get statusDisplay => switch (status) {
    'working' => 'Working',
    'in_progress' => 'In Progress',
    'completed' => 'Completed',
    'incomplete' => 'Incomplete',
    _ => 'Initial',
  };

  String get percentageDisplay => '${progressPercentage.toStringAsFixed(0)}%';
}

/// All valid progress status codes in display order.
const kProgressStatuses = [
  ('initial', 'Initial'),
  ('working', 'Working'),
  ('in_progress', 'In Progress'),
  ('completed', 'Completed'),
  ('incomplete', 'Incomplete'),
];
