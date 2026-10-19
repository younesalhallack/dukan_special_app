import '../../core/currency/currency.dart';
import '../../core/currency/money.dart';
import 'supplier.dart';

/// What the shop owes a supplier, per currency. Positive means the shop owes
/// the supplier; negative means the supplier holds an advance of the shop.
class SupplierBalance {
  const SupplierBalance(this.amounts);

  static const SupplierBalance zero = SupplierBalance(<Currency, int>{});

  final Map<Currency, int> amounts;

  int of(Currency currency) => amounts[currency] ?? 0;
  bool get isZero => amounts.values.every((value) => value == 0);

  /// The shop owes the supplier something in at least one currency.
  bool get owed => amounts.values.any((value) => value > 0);

  /// The shop has an advance with the supplier in at least one currency.
  bool get hasAdvance => amounts.values.any((value) => value < 0);

  /// Sum of what the shop owes, expressed in [base] at [rate].
  /// Advances are not subtracted.
  int owedIn(Currency base, double rate) {
    var total = 0;
    amounts.forEach((currency, value) {
      if (value > 0) {
        total += Money.convert(value, from: currency, to: base, rate: rate);
      }
    });
    return total;
  }
}

class SupplierWithBalance {
  const SupplierWithBalance({required this.supplier, required this.balance});

  final Supplier supplier;
  final SupplierBalance balance;
}
