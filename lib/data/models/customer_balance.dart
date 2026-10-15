import '../../core/currency/currency.dart';
import '../../core/currency/money.dart';
import 'customer.dart';

/// What a customer owes, per currency. Positive means the customer owes the
/// shop; negative means the shop owes the customer (credit in his favour).
class CustomerBalance {
  const CustomerBalance(this.amounts);

  static const CustomerBalance zero = CustomerBalance(<Currency, int>{});

  final Map<Currency, int> amounts;

  int of(Currency currency) => amounts[currency] ?? 0;
  bool get isZero => amounts.values.every((value) => value == 0);
  bool get owes => amounts.values.any((value) => value > 0);
  bool get hasCredit => amounts.values.any((value) => value < 0);

  /// Sum of what the customer owes, expressed in [base] at [rate].
  /// Credit balances are not subtracted.
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

class CustomerWithBalance {
  const CustomerWithBalance({required this.customer, required this.balance});

  final Customer customer;
  final CustomerBalance balance;
}
