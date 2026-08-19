class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.transactionCode,
    required this.transactionDate,
    required this.type,
    this.personId,
    this.personName,
    required this.amount,
    this.quantity,
    required this.purpose,
    required this.paymentMethod,
    this.referenceNumber,
    this.remarks,
    this.schemeId,
    this.schemeName,
    this.siteId,
    this.siteName,
  });

  final String id;
  final String transactionCode;
  final DateTime transactionDate;
  final String type; // 'received' or 'paid'
  final String? personId;
  final String? personName;
  final double amount;
  final double? quantity;
  final String purpose;
  final String paymentMethod;
  final String? referenceNumber;
  final String? remarks;
  final String? schemeId;
  final String? schemeName;
  final String? siteId;
  final String? siteName;

  bool get isReceived => type == 'received';
  bool get isPaid => type == 'paid';

  String get formattedAmount {
    final prefix = isReceived ? '+ Rs.' : '- Rs.';
    return '$prefix ${amount.toStringAsFixed(2)}';
  }

  String get paymentMethodDisplay {
    return switch (paymentMethod) {
      'bank_transfer' => 'Bank Transfer',
      'cheque' => 'Cheque',
      'online' => 'Online',
      'other' => 'Other',
      _ => 'Cash',
    };
  }
}
