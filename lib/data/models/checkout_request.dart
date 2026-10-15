import '../../core/currency/currency.dart';
import 'sale_transaction.dart';

/// One priced line of a sale. Amounts are minor units of the invoice currency.
class CheckoutLine {
  const CheckoutLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.lineTotal,
  });

  final int productId;
  final String productName;
  final double quantity;
  final int unitPrice;
  final int unitCost;
  final int lineTotal;

  /// Cost of this line, used for the invoice's `total_cost`.
  int get lineCost => (unitCost * quantity).round();
}

/// Everything needed to record a sale in one atomic step.
class CheckoutRequest {
  const CheckoutRequest({
    required this.currency,
    required this.exchangeRate,
    required this.lines,
    this.discountAmount = 0,
    this.paymentType = PaymentType.cash,
    this.paidAmount,
    this.customerId,
    this.note,
  });

  final Currency currency;

  /// SYP per 1 USD at the moment of the sale; stored on the invoice.
  final double exchangeRate;
  final List<CheckoutLine> lines;
  final int discountAmount;
  final PaymentType paymentType;

  /// Only used for credit sales (amount paid now). Cash sales are fully paid.
  final int? paidAmount;

  /// Required for credit sales.
  final int? customerId;
  final String? note;
}
