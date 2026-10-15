import 'package:flutter_test/flutter_test.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/features/pos/logic/cart_calculator.dart';

CartLine line({
  int id = 1,
  int sale = 1000,
  Currency saleCurrency = Currency.usd,
  int cost = 600,
  Currency costCurrency = Currency.usd,
  double quantity = 1,
}) {
  return CartLine(
    productId: id,
    name: 'p$id',
    salePrice: sale,
    saleCurrency: saleCurrency,
    costPrice: cost,
    costCurrency: costCurrency,
    quantity: quantity,
    stockQuantity: 100,
  );
}

CartTotals calc(
  List<CartLine> lines, {
  Currency currency = Currency.syp,
  double rate = 15000,
  int step = 100,
  int discount = 0,
}) {
  return CartCalculator.calculate(
    lines: lines,
    currency: currency,
    rate: rate,
    sypStep: step,
    discount: discount,
  );
}

void main() {
  test('a USD product in an SYP invoice (price and cost at the rate)', () {
    final totals = calc([line(quantity: 2)]);
    final item = totals.lines.single;
    expect(item.unitPrice, 150000); // $10.00 * 15000
    expect(item.unitCost, 90000); // $6.00 * 15000
    expect(item.lineTotal, 300000);
    expect(totals.subtotal, 300000);
    expect(totals.total, 300000);
    expect(totals.totalCost, 180000);
    expect(totals.profit, 120000);
    expect(totals.rate, 15000);
  });

  test('the SYP unit price is rounded up to the step, cost is not rounded', () {
    final totals = calc([line(sale: 99, cost: 33, quantity: 3)]);
    final item = totals.lines.single;
    expect(item.unitPrice, 14900); // 0.99 * 15000 = 14850 -> 14900
    expect(item.lineTotal, 44700);
    expect(item.unitCost, 4950); // 0.33 * 15000, exact
    expect(totals.totalCost, 14850);
  });

  test('fractional quantities round the SYP line total up to the step', () {
    final totals = calc([line(sale: 100, cost: 50, quantity: 0.333)]);
    // unit 15000 SYP * 0.333 = 4995 -> 5000
    expect(totals.lines.single.lineTotal, 5000);
  });

  test('an SYP-priced product keeps its exact price in an SYP invoice', () {
    final totals = calc([
      line(sale: 14850, saleCurrency: Currency.syp, cost: 9000, costCurrency: Currency.syp),
    ]);
    expect(totals.lines.single.unitPrice, 14850);
    expect(totals.lines.single.lineTotal, 14850);
    expect(totals.profit, 14850 - 9000);
  });

  test('an SYP product in a USD invoice is converted to cents', () {
    final totals = calc(
      [line(sale: 150000, saleCurrency: Currency.syp, cost: 90000, costCurrency: Currency.syp)],
      currency: Currency.usd,
    );
    expect(totals.lines.single.unitPrice, 1000);
    expect(totals.lines.single.unitCost, 600);
    expect(totals.total, 1000);
    expect(totals.profit, 400);
  });

  test('a USD product in a USD invoice is untouched', () {
    final totals = calc([line(sale: 1250, cost: 700, quantity: 2)], currency: Currency.usd);
    expect(totals.lines.single.unitPrice, 1250);
    expect(totals.total, 2500);
    expect(totals.totalCost, 1400);
  });

  test('the discount reduces the total and the profit', () {
    final totals = calc([line(quantity: 2)], discount: 50000);
    expect(totals.subtotal, 300000);
    expect(totals.discount, 50000);
    expect(totals.total, 250000);
    expect(totals.profit, 250000 - 180000);
  });

  test('the discount is clamped between zero and the subtotal', () {
    expect(calc([line()], discount: 999999999).total, 0);
    expect(calc([line()], discount: -5).discount, 0);
  });

  test('several lines are summed; an empty cart is zero', () {
    final totals = calc([line(id: 1), line(id: 2, sale: 500, cost: 200)]);
    expect(totals.lines, hasLength(2));
    expect(totals.subtotal, 150000 + 75000);
    expect(totals.totalCost, 90000 + 30000);

    final empty = calc(const []);
    expect(empty.isEmpty, isTrue);
    expect(empty.total, 0);
    expect(empty.profit, 0);
  });

  test('a different exchange rate gives different prices', () {
    expect(calc([line()], rate: 15000).total, 150000);
    expect(calc([line()], rate: 16000).total, 160000);
  });
}
