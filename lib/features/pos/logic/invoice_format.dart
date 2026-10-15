import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/sale_transaction.dart';

/// Formats an invoice amount for display. With dual currency on, the amount
/// is also shown in the other currency using the invoice's FROZEN rate.
String invoiceAmountText(int amount, SaleTransaction invoice, AppSettings s) {
  String show(Currency target) {
    final value = Money.salePriceIn(
      amountMinor: amount,
      from: invoice.currency,
      to: target,
      rate: invoice.exchangeRate,
      sypStep: s.sypRoundingStep,
    );
    return Money.format(value, target, digits: s.digitStyle);
  }

  final first = s.baseCurrency ?? invoice.currency;
  if (!s.showDualCurrency) return show(invoice.currency);
  return '${show(first)}  •  ${show(first.other)}';
}
