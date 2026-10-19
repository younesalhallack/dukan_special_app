import 'package:flutter_test/flutter_test.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/features/purchases/logic/purchase_calculator.dart';

PurchaseDraftLine line({
  int id = 1,
  double quantity = 1,
  int cost = 600,
  Currency costCurrency = Currency.usd,
  int previous = 600,
  Currency previousCurrency = Currency.usd,
}) {
  return PurchaseDraftLine(
    productId: id,
    name: 'p$id',
    quantity: quantity,
    enteredCost: cost,
    enteredCurrency: costCurrency,
    previousCost: previous,
    previousCurrency: previousCurrency,
  );
}

PurchaseTotals calc(
  List<PurchaseDraftLine> lines, {
  Currency currency = Currency.usd,
  double rate = 15000,
  int discount = 0,
}) {
  return PurchaseCalculator.calculate(
    lines: lines,
    currency: currency,
    rate: rate,
    discount: discount,
  );
}

void main() {
  group('calculate', () {
    test('a USD cost in a USD invoice is untouched', () {
      final totals = calc([line(quantity: 10)]);
      expect(totals.lines.single.unitCost, 600);
      expect(totals.lines.single.lineTotal, 6000);
      expect(totals.subtotal, 6000);
      expect(totals.total, 6000);
    });

    test('a USD cost in an SYP invoice is converted at the invoice rate', () {
      final totals = calc([line(quantity: 2)], currency: Currency.syp);
      expect(totals.lines.single.unitCost, 90000);
      expect(totals.lines.single.lineTotal, 180000);
      expect(totals.rate, 15000);
    });

    test('an SYP cost in a USD invoice is converted to cents', () {
      final totals = calc([line(cost: 90000, costCurrency: Currency.syp)]);
      expect(totals.lines.single.unitCost, 600);
    });

    test('the same line can be shown in either currency without losing precision', () {
      final draft = [line(cost: 90000, costCurrency: Currency.syp, quantity: 3)];
      expect(calc(draft, currency: Currency.syp).total, 270000);
      expect(calc(draft, currency: Currency.usd).total, 1800);
      expect(calc(draft, currency: Currency.syp).total, 270000);
    });

    test('costs are never rounded to the SYP step', () {
      final totals = calc(
        [line(cost: 15000, costCurrency: Currency.syp, quantity: 0.333)],
        currency: Currency.syp,
      );
      expect(totals.lines.single.lineTotal, 4995);
    });

    test('the discount reduces the total and is clamped to the subtotal', () {
      expect(calc([line(quantity: 10)], discount: 1000).total, 5000);
      expect(calc([line(quantity: 10)], discount: 1000).discount, 1000);
      expect(calc([line(quantity: 10)], discount: 999999).total, 0);
      expect(calc([line(quantity: 10)], discount: -5).discount, 0);
    });

    test('several lines are summed; an empty draft is zero', () {
      final totals = calc([line(id: 1, quantity: 2), line(id: 2, cost: 250)]);
      expect(totals.lines, hasLength(2));
      expect(totals.subtotal, 1200 + 250);
      final empty = calc(const []);
      expect(empty.isEmpty, isTrue);
      expect(empty.total, 0);
    });

    test('the exchange rate of the invoice is what converts', () {
      expect(calc([line()], currency: Currency.syp, rate: 15000).total, 90000);
      expect(calc([line()], currency: Currency.syp, rate: 16000).total, 96000);
    });
  });

  group('costChangePercent', () {
    double? change({
      int unitCost = 660,
      Currency currency = Currency.usd,
      int previous = 600,
      Currency previousCurrency = Currency.usd,
      double rate = 15000,
    }) {
      return PurchaseCalculator.costChangePercent(
        unitCost: unitCost,
        currency: currency,
        rate: rate,
        previousCost: previous,
        previousCurrency: previousCurrency,
      );
    }

    test('increase and decrease in the same currency', () {
      expect(change(), closeTo(10, 1e-9));
      expect(change(unitCost: 540), closeTo(-10, 1e-9));
      expect(change(unitCost: 600), closeTo(0, 1e-9));
    });

    test('compares in the product cost currency', () {
      // 99,000 SYP at 15000 is $6.60, against a previous cost of $6.00
      expect(
        change(unitCost: 99000, currency: Currency.syp),
        closeTo(10, 1e-9),
      );
    });

    test('unknown costs give no percentage', () {
      expect(change(previous: 0), isNull);
      expect(change(unitCost: 0), isNull);
    });
  });
}
