import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../data/models/checkout_request.dart';

/// A product in the cart, with the prices it had when it was added.
class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.salePrice,
    required this.saleCurrency,
    required this.costPrice,
    required this.costCurrency,
    required this.quantity,
    required this.stockQuantity,
  });

  final int productId;
  final String name;
  final int salePrice;
  final Currency saleCurrency;
  final int costPrice;
  final Currency costCurrency;
  final double quantity;

  /// Stock when the product was added; only used to warn about overselling.
  final double stockQuantity;

  CartLine copyWith({double? quantity}) {
    return CartLine(
      productId: productId,
      name: name,
      salePrice: salePrice,
      saleCurrency: saleCurrency,
      costPrice: costPrice,
      costCurrency: costCurrency,
      quantity: quantity ?? this.quantity,
      stockQuantity: stockQuantity,
    );
  }
}

/// The priced cart. [lines] has the same order as the cart lines.
class CartTotals {
  const CartTotals({
    required this.lines,
    required this.currency,
    required this.rate,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.totalCost,
  });

  final List<CheckoutLine> lines;
  final Currency currency;

  /// SYP per 1 USD used for this calculation.
  final double rate;
  final int subtotal;
  final int discount;
  final int total;
  final int totalCost;

  int get profit => total - totalCost;
  bool get isEmpty => lines.isEmpty;
}

/// Prices a cart in the chosen invoice currency. Pure and deterministic.
abstract final class CartCalculator {
  static CartTotals calculate({
    required List<CartLine> lines,
    required Currency currency,
    required double rate,
    required int sypStep,
    int discount = 0,
  }) {
    final priced = <CheckoutLine>[];
    var subtotal = 0;
    var cost = 0;

    for (final line in lines) {
      // The unit price is what the customer sees on the shelf: a price
      // derived from another currency is rounded the same way as in the lists.
      final unitPrice = Money.salePriceIn(
        amountMinor: line.salePrice,
        from: line.saleCurrency,
        to: currency,
        rate: rate,
        sypStep: sypStep,
      );
      // Cost is converted at the frozen rate without rounding, for profit.
      final unitCost = Money.convert(
        line.costPrice,
        from: line.costCurrency,
        to: currency,
        rate: rate,
      );

      var lineTotal = (unitPrice * line.quantity).round();
      // Whole quantities are already exact multiples of the unit price.
      // Fractional ones (weights) are rounded up to the SYP step.
      final fractional = line.quantity != line.quantity.roundToDouble();
      if (fractional && currency == Currency.syp) {
        lineTotal = Money.roundUpToStep(lineTotal, sypStep);
      }

      final item = CheckoutLine(
        productId: line.productId,
        productName: line.name,
        quantity: line.quantity,
        unitPrice: unitPrice,
        unitCost: unitCost,
        lineTotal: lineTotal,
      );
      priced.add(item);
      subtotal += lineTotal;
      cost += item.lineCost;
    }

    var appliedDiscount = discount < 0 ? 0 : discount;
    if (appliedDiscount > subtotal) appliedDiscount = subtotal;

    return CartTotals(
      lines: priced,
      currency: currency,
      rate: rate,
      subtotal: subtotal,
      discount: appliedDiscount,
      total: subtotal - appliedDiscount,
      totalCost: cost,
    );
  }
}
