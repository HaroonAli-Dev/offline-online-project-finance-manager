/// Financial totals calculated from bills belonging to a single scheme.
class BillTotals {
  const BillTotals({required this.totalBilled, required this.totalPaid});

  /// Sum of all non-deleted bill amounts (PKR).
  final double totalBilled;

  /// Sum of bill amounts where status = 'paid' (PKR).
  final double totalPaid;

  /// Outstanding = totalBilled - totalPaid.
  double get outstanding => totalBilled - totalPaid;

  static const zero = BillTotals(totalBilled: 0, totalPaid: 0);
}
