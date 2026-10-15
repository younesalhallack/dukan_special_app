import '../errors/app_exceptions.dart';
import 'currency.dart';
import 'money.dart';

/// Currency maths for debt payments. A customer may pay in one currency
/// (the "pay currency") to settle a debt in another (the "applied currency").
abstract final class PaymentMath {
  /// What a payment of [amount] is worth in [appliedCurrency] at [rate]
  /// (rate = SYP per 1 USD). No step rounding.
  static int appliedAmount({
    required int amount,
    required Currency payCurrency,
    required Currency appliedCurrency,
    required double rate,
  }) {
    return Money.convert(
      amount,
      from: payCurrency,
      to: appliedCurrency,
      rate: rate,
    );
  }

  /// How far (in minor units of the applied currency) a converted payment may
  /// exceed the debt and still count as paying it exactly. Converting between
  /// currencies rounds, so paying "exactly the debt" can overshoot by up to
  /// one minor unit of the pay currency.
  static int tolerance({
    required Currency payCurrency,
    required Currency appliedCurrency,
    required double rate,
  }) {
    if (payCurrency == appliedCurrency) return 0;
    return Money.convert(1, from: payCurrency, to: appliedCurrency, rate: rate) + 1;
  }

  /// The amount credited to the debt for a payment, never more than
  /// [balance]. Throws [AppException]: `invalidAmount` when the payment is
  /// worth nothing, `paymentExceedsDebt` when it is clearly more than owed.
  static int resolveApplied({
    required int amount,
    required Currency payCurrency,
    required Currency appliedCurrency,
    required double rate,
    required int balance,
  }) {
    final applied = appliedAmount(
      amount: amount,
      payCurrency: payCurrency,
      appliedCurrency: appliedCurrency,
      rate: rate,
    );
    if (applied <= 0) throw const AppException(AppError.invalidAmount);
    if (applied <= balance) return applied;
    final slack = tolerance(
      payCurrency: payCurrency,
      appliedCurrency: appliedCurrency,
      rate: rate,
    );
    if (applied - balance <= slack) return balance;
    throw const AppException(AppError.paymentExceedsDebt);
  }

  /// The smallest amount in [payCurrency] that settles [balance] completely.
  static int settlementAmount({
    required int balance,
    required Currency payCurrency,
    required Currency appliedCurrency,
    required double rate,
  }) {
    if (payCurrency == appliedCurrency) return balance;
    var amount = Money.convert(
      balance,
      from: appliedCurrency,
      to: payCurrency,
      rate: rate,
    );
    var guard = 0;
    while (guard < 100000 &&
        appliedAmount(
              amount: amount,
              payCurrency: payCurrency,
              appliedCurrency: appliedCurrency,
              rate: rate,
            ) <
            balance) {
      amount += 1;
      guard++;
    }
    return amount;
  }
}
