import 'package:flutter_test/flutter_test.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/data/models/purchase.dart';
import 'package:dukan_special_app/data/models/sale_transaction.dart';
import 'package:dukan_special_app/features/purchases/logic/purchases_summary.dart';

Purchase purchase({
  required int id,
  required Currency currency,
  required double rate,
  required int total,
  InvoiceStatus status = InvoiceStatus.completed,
}) {
  return Purchase(
    id: id,
    purchaseNumber: 'PUR-$id',
    supplierId: null,
    supplierInvoiceNumber: null,
    currency: currency,
    exchangeRate: rate,
    totalAmount: total,
    discountAmount: 0,
    paidAmount: total,
    paymentType: PaymentType.cash,
    status: status,
    note: null,
    purchaseDate: '2026-10-14T10:00:00.000Z',
    createdAt: '2026-10-14T10:00:00.000Z',
  );
}

void main() {
  test('each purchase is converted with its own rate', () {
    final summary = PurchasesSummary.fromPurchases([
      purchase(id: 1, currency: Currency.usd, rate: 15000, total: 1000),
      purchase(id: 2, currency: Currency.usd, rate: 16000, total: 2000),
      purchase(id: 3, currency: Currency.syp, rate: 16000, total: 30000),
    ], Currency.syp);

    expect(summary.count, 3);
    expect(summary.totalsByCurrency[Currency.usd], 3000);
    expect(summary.totalsByCurrency[Currency.syp], 30000);
    expect(summary.totalInBase, 150000 + 320000 + 30000);
  });

  test('voided purchases are counted but not added', () {
    final summary = PurchasesSummary.fromPurchases([
      purchase(id: 1, currency: Currency.syp, rate: 15000, total: 5000),
      purchase(
        id: 2,
        currency: Currency.syp,
        rate: 15000,
        total: 99999,
        status: InvoiceStatus.voided,
      ),
    ], Currency.syp);
    expect(summary.count, 1);
    expect(summary.voidedCount, 1);
    expect(summary.totalInBase, 5000);
  });

  test('a USD base currency converts SYP purchases back to dollars', () {
    final summary = PurchasesSummary.fromPurchases([
      purchase(id: 1, currency: Currency.syp, rate: 15000, total: 150000),
    ], Currency.usd);
    expect(summary.totalInBase, 1000);
  });

  test('no purchases gives zeros', () {
    final summary = PurchasesSummary.fromPurchases(const [], Currency.usd);
    expect(summary.count, 0);
    expect(summary.totalInBase, 0);
    expect(summary.totalsByCurrency, isEmpty);
  });
}
