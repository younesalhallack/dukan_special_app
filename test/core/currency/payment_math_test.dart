import 'package:flutter_test/flutter_test.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/core/currency/payment_math.dart';
import 'package:dukan_special_app/core/errors/app_exceptions.dart';

Matcher _appError(AppError error) =>
    isA<AppException>().having((e) => e.error, 'error', error);

void main() {
  group('appliedAmount', () {
    test('converts between currencies at the rate', () {
      expect(
        PaymentMath.appliedAmount(
          amount: 150000,
          payCurrency: Currency.syp,
          appliedCurrency: Currency.usd,
          rate: 15000,
        ),
        1000,
      );
      expect(
        PaymentMath.appliedAmount(
          amount: 1000,
          payCurrency: Currency.usd,
          appliedCurrency: Currency.syp,
          rate: 15000,
        ),
        150000,
      );
    });

    test('same currency is unchanged', () {
      expect(
        PaymentMath.appliedAmount(
          amount: 777,
          payCurrency: Currency.syp,
          appliedCurrency: Currency.syp,
          rate: 15000,
        ),
        777,
      );
    });
  });

  group('tolerance', () {
    test('none for the same currency', () {
      expect(
        PaymentMath.tolerance(
          payCurrency: Currency.syp,
          appliedCurrency: Currency.syp,
          rate: 15000,
        ),
        0,
      );
    });

    test('one unit of the pay currency expressed in the applied currency, plus one', () {
      // paying dollars (a cent is 150 SYP) against an SYP debt
      expect(
        PaymentMath.tolerance(
          payCurrency: Currency.usd,
          appliedCurrency: Currency.syp,
          rate: 15000,
        ),
        151,
      );
      // paying SYP against a dollar debt: a pound is far less than a cent
      expect(
        PaymentMath.tolerance(
          payCurrency: Currency.syp,
          appliedCurrency: Currency.usd,
          rate: 15000,
        ),
        1,
      );
    });
  });

  group('resolveApplied', () {
    int resolve(
      int amount,
      Currency pay,
      Currency applied,
      int balance, {
      double rate = 15000,
    }) {
      return PaymentMath.resolveApplied(
        amount: amount,
        payCurrency: pay,
        appliedCurrency: applied,
        rate: rate,
        balance: balance,
      );
    }

    test('a partial payment is applied as converted', () {
      expect(resolve(75000, Currency.syp, Currency.usd, 1000), 500);
      expect(resolve(30000, Currency.syp, Currency.syp, 80000), 30000);
    });

    test('paying exactly the debt is accepted', () {
      expect(resolve(80000, Currency.syp, Currency.syp, 80000), 80000);
    });

    test('a payment clearly above the debt is rejected', () {
      expect(
        () => resolve(80001, Currency.syp, Currency.syp, 80000),
        throwsA(_appError(AppError.paymentExceedsDebt)),
      );
      expect(
        () => resolve(200000, Currency.syp, Currency.usd, 1000),
        throwsA(_appError(AppError.paymentExceedsDebt)),
      );
    });

    test('a rounding excess within the tolerance is clamped to the debt', () {
      // rate 15333: 979 cents = 150,110 SYP, the debt is 150,000 SYP
      expect(
        resolve(979, Currency.usd, Currency.syp, 150000, rate: 15333),
        150000,
      );
    });

    test('a payment worth nothing is invalid', () {
      expect(
        () => resolve(1, Currency.syp, Currency.usd, 1000),
        throwsA(_appError(AppError.invalidAmount)),
      );
    });
  });

  group('settlementAmount', () {
    test('same currency is the balance itself', () {
      expect(
        PaymentMath.settlementAmount(
          balance: 80000,
          payCurrency: Currency.syp,
          appliedCurrency: Currency.syp,
          rate: 15000,
        ),
        80000,
      );
    });

    test('a dollar debt paid in pounds', () {
      expect(
        PaymentMath.settlementAmount(
          balance: 1000,
          payCurrency: Currency.syp,
          appliedCurrency: Currency.usd,
          rate: 15000,
        ),
        150000,
      );
    });

    test('rounds up so the payment really covers the debt', () {
      final amount = PaymentMath.settlementAmount(
        balance: 150000,
        payCurrency: Currency.usd,
        appliedCurrency: Currency.syp,
        rate: 15333,
      );
      expect(amount, 979); // 978 cents would leave a few pounds unpaid
      // ... and resolving that amount closes the debt exactly
      expect(
        PaymentMath.resolveApplied(
          amount: amount,
          payCurrency: Currency.usd,
          appliedCurrency: Currency.syp,
          rate: 15333,
          balance: 150000,
        ),
        150000,
      );
    });
  });
}
