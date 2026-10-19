import '../../core/currency/currency.dart';
import 'sale_transaction.dart';

/// A purchase invoice (row of the `purchases` table).
///
/// All amounts are minor units of [currency]. [exchangeRate] (SYP per 1 USD)
/// is the rate frozen on the invoice.
class Purchase {
  const Purchase({
    required this.id,
    required this.purchaseNumber,
    required this.supplierId,
    required this.supplierInvoiceNumber,
    required this.currency,
    required this.exchangeRate,
    required this.totalAmount,
    required this.discountAmount,
    required this.paidAmount,
    required this.paymentType,
    required this.status,
    required this.note,
    required this.purchaseDate,
    required this.createdAt,
  });

  final int id;
  final String purchaseNumber;
  final int? supplierId;

  /// The number printed on the supplier's own invoice.
  final String? supplierInvoiceNumber;
  final Currency currency;
  final double exchangeRate;

  /// Amount to pay, after the discount.
  final int totalAmount;
  final int discountAmount;
  final int paidAmount;
  final PaymentType paymentType;
  final InvoiceStatus status;
  final String? note;
  final String purchaseDate;
  final String createdAt;

  int get subtotal => totalAmount + discountAmount;

  /// What the shop still owes on this invoice (credit purchases).
  int get debtAmount => totalAmount - paidAmount;

  bool get isVoided => status == InvoiceStatus.voided;
  DateTime get purchaseDateLocal => DateTime.parse(purchaseDate).toLocal();

  factory Purchase.fromMap(Map<String, Object?> map) {
    return Purchase(
      id: map['id'] as int,
      purchaseNumber: map['purchase_number'] as String,
      supplierId: map['supplier_id'] as int?,
      supplierInvoiceNumber: map['supplier_invoice_number'] as String?,
      currency: Currency.fromCode(map['currency'] as String),
      exchangeRate: (map['exchange_rate'] as num).toDouble(),
      totalAmount: map['total_amount'] as int,
      discountAmount: (map['discount_amount'] as int?) ?? 0,
      paidAmount: map['paid_amount'] as int,
      paymentType: PaymentType.fromCode(map['payment_type'] as String),
      status: InvoiceStatus.fromCode(map['status'] as String),
      note: map['note'] as String?,
      purchaseDate: map['purchase_date'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}

/// One line of a purchase invoice (row of `purchase_items`).
class PurchaseItem {
  const PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
  });

  final int id;
  final int purchaseId;
  final int? productId;
  final String productName;
  final double quantity;
  final int unitCost;
  final int lineTotal;

  factory PurchaseItem.fromMap(Map<String, Object?> map) {
    return PurchaseItem(
      id: map['id'] as int,
      purchaseId: map['purchase_id'] as int,
      productId: map['product_id'] as int?,
      productName: map['product_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitCost: map['unit_cost'] as int,
      lineTotal: map['line_total'] as int,
    );
  }
}

/// A purchase invoice together with its lines.
class PurchaseDetails {
  const PurchaseDetails({required this.purchase, required this.items});

  final Purchase purchase;
  final List<PurchaseItem> items;
}
