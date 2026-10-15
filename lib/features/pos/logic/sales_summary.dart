import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../data/models/sale_transaction.dart';

/// Totals of a list of invoices. Voided invoices are counted separately and
/// never added to the amounts. Every invoice is converted to the base
/// currency with ITS OWN frozen exchange rate, not today's rate.
class SalesSummary {
  const SalesSummary({
    required this.baseCurrency,
    required this.count,
    required this.voidedCount,
    required this.totalsByCurrency,
    required this.totalInBase,
    required this.profitInBase,
  });

  final Currency baseCurrency;
  final int count;
  final int voidedCount;
  final Map<Currency, int> totalsByCurrency;
  final int totalInBase;
  final int profitInBase;

  factory SalesSummary.fromInvoices(
    List<SaleTransaction> invoices,
    Currency baseCurrency,
  ) {
    var count = 0;
    var voided = 0;
    var totalBase = 0;
    var profitBase = 0;
    final byCurrency = <Currency, int>{};

    for (final invoice in invoices) {
      if (invoice.isVoided) {
        voided++;
        continue;
      }
      count++;
      byCurrency[invoice.currency] =
          (byCurrency[invoice.currency] ?? 0) + invoice.totalAmount;
      totalBase += Money.convert(
        invoice.totalAmount,
        from: invoice.currency,
        to: baseCurrency,
        rate: invoice.exchangeRate,
      );
      profitBase += Money.convert(
        invoice.profit,
        from: invoice.currency,
        to: baseCurrency,
        rate: invoice.exchangeRate,
      );
    }

    return SalesSummary(
      baseCurrency: baseCurrency,
      count: count,
      voidedCount: voided,
      totalsByCurrency: byCurrency,
      totalInBase: totalBase,
      profitInBase: profitBase,
    );
  }
}
