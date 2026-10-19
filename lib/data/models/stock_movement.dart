/// Allowed values of `stock_movements.reason`.
abstract final class StockReasons {
  static const sale = 'sale';
  static const restock = 'restock';
  static const adjustment = 'adjustment';
  static const voidSale = 'void';
}

/// Machine-readable notes the UI can localize.
abstract final class StockNotes {
  static const openingStock = 'opening_stock';
}

/// A change of a product's quantity (row of `stock_movements`).
class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.changeQty,
    required this.reason,
    required this.refTransactionId,
    required this.refPurchaseId,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final int productId;
  final double changeQty;
  final String reason;
  final int? refTransactionId;

  /// Set for movements caused by a purchase invoice.
  final int? refPurchaseId;
  final String? note;
  final String createdAt;

  factory StockMovement.fromMap(Map<String, Object?> map) {
    return StockMovement(
      id: map['id'] as int,
      productId: map['product_id'] as int,
      changeQty: (map['change_qty'] as num).toDouble(),
      reason: map['reason'] as String,
      refTransactionId: map['ref_transaction_id'] as int?,
      refPurchaseId: map['ref_purchase_id'] as int?,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
