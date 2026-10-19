import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/purchase.dart';

/// Formats a purchase amount for display. With dual currency on, the amount
/// is also shown in the other currency using the purchase's own rate.
String purchaseAmountText(int amount, Purchase purchase, AppSettings s) {
  String show(Currency target) {
    final value = Money.convert(
      amount,
      from: purchase.currency,
      to: target,
      rate: purchase.exchangeRate,
    );
    return Money.format(value, target, digits: s.digitStyle);
  }

  final first = s.baseCurrency ?? purchase.currency;
  if (!s.showDualCurrency) return show(purchase.currency);
  return '${show(first)}  •  ${show(first.other)}';
}
