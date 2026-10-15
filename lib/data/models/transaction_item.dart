/// One line of an invoice (row of `transaction_items`). Prices and costs are
/// minor units of the invoice currency, frozen at sale time.
class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.lineTotal,
  });

  final int id;
  final int transactionId;
  final int? productId;
  final String productName;
  final double quantity;
  final int unitPrice;
  final int unitCost;
  final int lineTotal;

  factory TransactionItem.fromMap(Map<String, Object?> map) {
    return TransactionItem(
      id: map['id'] as int,
      transactionId: map['transaction_id'] as int,
      productId: map['product_id'] as int?,
      productName: map['product_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: map['unit_price'] as int,
      unitCost: map['unit_cost'] as int,
      lineTotal: map['line_total'] as int,
    );
  }
}
