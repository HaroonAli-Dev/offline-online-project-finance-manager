/// Domain model for a reminder record.
class ReminderModel {
  const ReminderModel({
    required this.id,
    required this.title,
    this.description,
    this.dueAt,
    required this.priority,
    required this.isDone,
    this.doneAt,
    this.schemeId,
    this.schemeName,
    this.siteId,
    this.siteName,
    this.remarks,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime? dueAt;

  /// 'low', 'medium', 'high'
  final String priority;
  final bool isDone;
  final DateTime? doneAt;
  final String? schemeId;
  final String? schemeName;
  final String? siteId;
  final String? siteName;
  final String? remarks;
  final DateTime createdAt;

  String get priorityDisplay => switch (priority) {
    'high' => 'High',
    'low' => 'Low',
    _ => 'Medium',
  };

  bool get isOverdue =>
      !isDone && dueAt != null && dueAt!.isBefore(DateTime.now().toUtc());
}

/// All valid priority codes in display order.
const kReminderPriorities = [
  ('low', 'Low'),
  ('medium', 'Medium'),
  ('high', 'High'),
];
