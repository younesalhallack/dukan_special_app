import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../data/models/purchase.dart';

/// Totals of a list of purchases. Voided purchases are counted separately and
/// never added. Every purchase is converted to the base currency with ITS OWN
/// exchange rate, not today's rate.
class PurchasesSummary {
  const PurchasesSummary({
    required this.baseCurrency,
    required this.count,
    required this.voidedCount,
    required this.totalsByCurrency,
    required this.totalInBase,
  });

  final Currency baseCurrency;
  final int count;
  final int voidedCount;
  final Map<Currency, int> totalsByCurrency;
  final int totalInBase;

  factory PurchasesSummary.fromPurchases(
    List<Purchase> purchases,
    Currency baseCurrency,
  ) {
    var count = 0;
    var voided = 0;
    var totalBase = 0;
    final byCurrency = <Currency, int>{};
    for (final purchase in purchases) {
      if (purchase.isVoided) {
        voided++;
        continue;
      }
      count++;
      byCurrency[purchase.currency] =
          (byCurrency[purchase.currency] ?? 0) + purchase.totalAmount;
      totalBase += Money.convert(
        purchase.totalAmount,
        from: purchase.currency,
        to: baseCurrency,
        rate: purchase.exchangeRate,
      );
    }
    return PurchasesSummary(
      baseCurrency: baseCurrency,
      count: count,
      voidedCount: voided,
      totalsByCurrency: byCurrency,
      totalInBase: totalBase,
    );
  }
}
