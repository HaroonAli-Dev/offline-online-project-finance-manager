class ExpenseModel {
  const ExpenseModel({
    required this.id,
    required this.expenseCode,
    required this.expenseDate,
    required this.category,
    required this.amount,
    required this.purpose,
    this.siteId,
    this.siteName,
    this.schemeId,
    this.schemeName,
    this.personId,
    this.personName,
    this.remarks,
    this.attachmentPath,
  });

  final String id;
  final String expenseCode;
  final DateTime expenseDate;
  final String category; // personal, labour, vehicle, office, security, dinner, material, miscellaneous
  final double amount;
  final String purpose;
  final String? siteId;
  final String? siteName;
  final String? schemeId;
  final String? schemeName;
  final String? personId;
  final String? personName;
  final String? remarks;
  final String? attachmentPath;

  String get formattedAmount => 'Rs. ${amount.toStringAsFixed(2)}';

  String get categoryDisplay {
    return switch (category) {
      'personal' => 'Personal',
      'labour' => 'Labour',
      'vehicle' => 'Vehicle',
      'office' => 'Office',
      'security' => 'Security',
      'dinner' => 'Dinner',
      'material' => 'Material',
      _ => 'Miscellaneous',
    };
  }
}
