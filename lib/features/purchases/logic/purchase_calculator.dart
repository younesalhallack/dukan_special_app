import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../data/models/purchase_request.dart';

/// A product on the purchase invoice being typed. The unit cost is kept in
/// the currency it was entered in, so switching the invoice currency back and
/// forth never loses precision.
class PurchaseDraftLine {
  const PurchaseDraftLine({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.enteredCost,
    required this.enteredCurrency,
    required this.previousCost,
    required this.previousCurrency,
  });

  final int productId;
  final String name;
  final double quantity;

  /// Unit cost in minor units of [enteredCurrency].
  final int enteredCost;
  final Currency enteredCurrency;

  /// The product's cost before this purchase (for the "cost changed" hint).
  final int previousCost;
  final Currency previousCurrency;

  PurchaseDraftLine copyWith({
    double? quantity,
    int? enteredCost,
    Currency? enteredCurrency,
  }) {
    return PurchaseDraftLine(
      productId: productId,
      name: name,
      quantity: quantity ?? this.quantity,
      enteredCost: enteredCost ?? this.enteredCost,
      enteredCurrency: enteredCurrency ?? this.enteredCurrency,
      previousCost: previousCost,
      previousCurrency: previousCurrency,
    );
  }
}

/// The purchase invoice priced in the invoice currency. [lines] has the same
/// order as the draft lines.
class PurchaseTotals {
  const PurchaseTotals({
    required this.lines,
    required this.currency,
    required this.rate,
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  final List<PurchaseLine> lines;
  final Currency currency;
  final double rate;
  final int subtotal;
  final int discount;
  final int total;

  bool get isEmpty => lines.isEmpty;
}

abstract final class PurchaseCalculator {
  /// Prices the draft in [currency] at [rate] (SYP per 1 USD). Costs are
  /// never rounded to the SYP step: a purchase records what was really paid.
  static PurchaseTotals calculate({
    required List<PurchaseDraftLine> lines,
    required Currency currency,
    required double rate,
    int discount = 0,
  }) {
    final priced = <PurchaseLine>[];
    var subtotal = 0;
    for (final line in lines) {
      final unitCost = Money.convert(
        line.enteredCost,
        from: line.enteredCurrency,
        to: currency,
        rate: rate,
      );
      final lineTotal = (unitCost * line.quantity).round();
      priced.add(PurchaseLine(
        productId: line.productId,
        productName: line.name,
        quantity: line.quantity,
        unitCost: unitCost,
        lineTotal: lineTotal,
      ));
      subtotal += lineTotal;
    }
    var applied = discount < 0 ? 0 : discount;
    if (applied > subtotal) applied = subtotal;
    return PurchaseTotals(
      lines: priced,
      currency: currency,
      rate: rate,
      subtotal: subtotal,
      discount: applied,
      total: subtotal - applied,
    );
  }

  /// How much the new unit cost differs from the product's previous cost, in
  /// percent. Null when either cost is unknown (zero).
  static double? costChangePercent({
    required int unitCost,
    required Currency currency,
    required double rate,
    required int previousCost,
    required Currency previousCurrency,
  }) {
    if (previousCost <= 0 || unitCost <= 0) return null;
    final newInPrevious = Money.convert(
      unitCost,
      from: currency,
      to: previousCurrency,
      rate: rate,
    );
    return (newInPrevious - previousCost) / previousCost * 100;
  }
}
