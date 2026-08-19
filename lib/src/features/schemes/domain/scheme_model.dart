class SchemeModel {
  const SchemeModel({
    required this.id,
    required this.schemeCode,
    required this.name,
    this.siteId,
    this.siteName,
    required this.budget,
    this.engineerId,
    this.engineerName,
    this.startDate,
    this.endDate,
    required this.status,
    required this.progressPercentage,
    this.incompleteReason,
    this.result,
    this.description,
  });

  final String id;
  final String schemeCode;
  final String name;
  final String? siteId;
  final String? siteName;
  final double budget;
  final String? engineerId;
  final String? engineerName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final double progressPercentage;
  final String? incompleteReason;
  final String? result;
  final String? description;

  String get formattedBudget {
    return 'Rs. ${budget.toStringAsFixed(2)}';
  }

  String get statusDisplay {
    return switch (status) {
      'working' => 'Working',
      'in_progress' => 'In Progress',
      'completed' => 'Completed',
      'incomplete' => 'Incomplete',
      _ => 'Initial',
    };
  }
}
