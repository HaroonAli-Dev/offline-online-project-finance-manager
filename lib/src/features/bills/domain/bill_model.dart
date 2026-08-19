/// Domain model for a project billing record.
///
/// Amount is stored internally in paisa in the database but exposed here
/// as PKR (double) for UI display — consistent with Expense/Transaction models.
class BillModel {
  const BillModel({
    required this.id,
    required this.schemeId,
    required this.schemeName,
    this.siteName,
    required this.billType,
    this.billNumber,
    required this.billDate,
    required this.amount,
    required this.status,
    this.remarks,
  });

  final String id;
  final String schemeId;
  final String schemeName;
  final String? siteName;

  /// Internal code: 'initial', 'first', 'second', 'third', 'fourth',
  /// 'final', 'other'.
  final String billType;

  /// Optional client reference number (e.g. "Bill No. 3/2026").
  final String? billNumber;

  final DateTime billDate;

  /// Amount in PKR (paisa / 100). Always >= 0.
  final double amount;

  /// 'draft', 'submitted', 'approved', 'paid', 'rejected'.
  final String status;

  final String? remarks;

  String get formattedAmount => 'Rs. ${amount.toStringAsFixed(2)}';

  String get billTypeDisplay => switch (billType) {
    'initial' => 'Initial Bill',
    'first' => 'First Bill',
    'second' => 'Second Bill',
    'third' => 'Third Bill',
    'fourth' => 'Fourth Bill',
    'final' => 'Final Bill',
    _ => 'Other Bill',
  };

  String get statusDisplay => switch (status) {
    'submitted' => 'Submitted',
    'approved' => 'Approved',
    'paid' => 'Paid',
    'rejected' => 'Rejected',
    _ => 'Draft',
  };
}

/// All valid bill type codes in display order.
const kBillTypes = [
  ('initial', 'Initial Bill'),
  ('first', 'First Bill'),
  ('second', 'Second Bill'),
  ('third', 'Third Bill'),
  ('fourth', 'Fourth Bill'),
  ('final', 'Final Bill'),
  ('other', 'Other Bill'),
];

/// All valid bill status codes in display order.
const kBillStatuses = [
  ('draft', 'Draft'),
  ('submitted', 'Submitted'),
  ('approved', 'Approved'),
  ('paid', 'Paid'),
  ('rejected', 'Rejected'),
];
