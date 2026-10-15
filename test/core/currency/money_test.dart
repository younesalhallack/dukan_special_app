import 'package:flutter_test/flutter_test.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/core/currency/money.dart';
import 'package:dukan_special_app/core/utils/digits.dart';

void main() {
  group('convert', () {
    test('USD to SYP', () {
      expect(
        Money.convert(1250, from: Currency.usd, to: Currency.syp, rate: 15000),
        187500,
      );
    });

    test('SYP to USD', () {
      expect(
        Money.convert(187500, from: Currency.syp, to: Currency.usd, rate: 15000),
        1250,
      );
    });

    test('same currency is returned unchanged', () {
      expect(
        Money.convert(777, from: Currency.syp, to: Currency.syp, rate: 15000),
        777,
      );
    });
  });

  group('rounding', () {
    test('roundUpToStep rounds up to the next multiple', () {
      expect(Money.roundUpToStep(17250, 100), 17300);
      expect(Money.roundUpToStep(17300, 100), 17300);
      expect(Money.roundUpToStep(1, 500), 500);
    });

    test('a step of 1 or an amount of 0 is unchanged', () {
      expect(Money.roundUpToStep(17251, 1), 17251);
      expect(Money.roundUpToStep(0, 100), 0);
    });

    test('salePriceIn rounds SYP up but leaves USD and same-currency alone', () {
      // 0.99 USD * 15000 = 14850 -> 14900 with step 100.
      expect(
        Money.salePriceIn(
          amountMinor: 99,
          from: Currency.usd,
          to: Currency.syp,
          rate: 15000,
          sypStep: 100,
        ),
        14900,
      );
      expect(
        Money.salePriceIn(
          amountMinor: 14850,
          from: Currency.syp,
          to: Currency.syp,
          rate: 15000,
          sypStep: 100,
        ),
        14850,
      );
      expect(
        Money.salePriceIn(
          amountMinor: 150000,
          from: Currency.syp,
          to: Currency.usd,
          rate: 15000,
          sypStep: 100,
        ),
        1000,
      );
    });

    test('suggestedRoundingStep follows the rate magnitude', () {
      expect(Money.suggestedRoundingStep(15000), 100);
      expect(Money.suggestedRoundingStep(1200), 10);
      expect(Money.suggestedRoundingStep(130), 1);
    });
  });

  group('format', () {
    test('USD uses two decimals and grouping', () {
      expect(Money.format(123456, Currency.usd), '1,234.56 \$');
      expect(Money.format(1250, Currency.usd, withSymbol: false), '12.50');
      expect(Money.format(5, Currency.usd, withSymbol: false), '0.05');
    });

    test('SYP has no decimals', () {
      expect(Money.format(1500000, Currency.syp), '1,500,000 ل.س');
      expect(Money.format(0, Currency.syp, withSymbol: false), '0');
    });

    test('negative amounts', () {
      expect(Money.format(-2500, Currency.usd, withSymbol: false), '-25.00');
    });

    test('Arabic-Indic digits', () {
      expect(
        Money.format(
          1500000,
          Currency.syp,
          digits: DigitStyle.arabicIndic,
        ),
        '١٬٥٠٠٬٠٠٠ ل.س',
      );
      expect(
        Money.format(
          1250,
          Currency.usd,
          digits: DigitStyle.arabicIndic,
          withSymbol: false,
        ),
        '١٢٫٥٠',
      );
    });

    test('formatRate groups and trims zeros', () {
      expect(Money.formatRate(15000), '15,000');
      expect(Money.formatRate(134.5), '134.5');
      expect(Money.formatRate(13450.25), '13,450.25');
    });
  });

  group('parse', () {
    test('plain and grouped numbers', () {
      expect(Money.parse('12.50', Currency.usd), 1250);
      expect(Money.parse('1,500,000', Currency.syp), 1500000);
      expect(Money.parse(' 15 000 ', Currency.syp), 15000);
    });

    test('Arabic-Indic digits and separators', () {
      expect(Money.parse('١٢٫٥٠', Currency.usd), 1250);
      expect(Money.parse('١٬٥٠٠', Currency.syp), 1500);
      expect(Money.parseDecimal('١٥٠٠٠'), 15000.0);
    });

    test('invalid input returns null', () {
      expect(Money.parse('', Currency.usd), isNull);
      expect(Money.parse('abc', Currency.usd), isNull);
      expect(Money.parse('12.5.3', Currency.usd), isNull);
      expect(Money.parse('-5', Currency.usd), isNull);
    });
  });

  group('isLargeRateChange', () {
    test('flags changes above 20 percent', () {
      expect(Money.isLargeRateChange(15000, 1500), isTrue);
      expect(Money.isLargeRateChange(15000, 18500), isTrue);
    });

    test('allows small changes', () {
      expect(Money.isLargeRateChange(15000, 15500), isFalse);
      expect(Money.isLargeRateChange(15000, 18000), isFalse);
    });
  });
}
