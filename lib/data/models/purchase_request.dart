import '../../core/currency/currency.dart';
import 'sale_transaction.dart';

/// One priced line of a purchase. Amounts are minor units of the invoice
/// currency.
class PurchaseLine {
  const PurchaseLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
  });

  final int productId;
  final String productName;
  final double quantity;
  final int unitCost;
  final int lineTotal;
}

/// Everything needed to record a purchase invoice in one atomic step.
class PurchaseRequest {
  const PurchaseRequest({
    required this.currency,
    required this.exchangeRate,
    required this.lines,
    required this.purchaseDate,
    this.discountAmount = 0,
    this.paymentType = PaymentType.cash,
    this.paidAmount,
    this.supplierId,
    this.supplierInvoiceNumber,
    this.note,
    this.updateCosts = true,
  });

  final Currency currency;

  /// SYP per 1 USD stored on the invoice (it may differ from the current rate).
  final double exchangeRate;
  final List<PurchaseLine> lines;
  final DateTime purchaseDate;
  final int discountAmount;
  final PaymentType paymentType;

  /// Only used for credit purchases (amount paid now). Cash purchases are
  /// fully paid.
  final int? paidAmount;

  /// Required for credit purchases.
  final int? supplierId;
  final String? supplierInvoiceNumber;
  final String? note;

  /// When true, each product's cost becomes the unit cost of this invoice
  /// (converted to the product's own cost currency).
  final bool updateCosts;
}
