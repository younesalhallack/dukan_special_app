import 'package:flutter_test/flutter_test.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/data/models/sale_transaction.dart';
import 'package:dukan_special_app/features/pos/logic/sales_summary.dart';

SaleTransaction invoice({
  required int id,
  required Currency currency,
  required double rate,
  required int total,
  required int cost,
  InvoiceStatus status = InvoiceStatus.completed,
}) {
  return SaleTransaction(
    id: id,
    invoiceNumber: 'INV-$id',
    customerId: null,
    currency: currency,
    exchangeRate: rate,
    totalAmount: total,
    discountAmount: 0,
    paidAmount: total,
    totalCost: cost,
    paymentType: PaymentType.cash,
    status: status,
    note: null,
    createdAt: '2026-10-14T10:00:00.000Z',
  );
}

void main() {
  test('each invoice is converted with its own frozen rate', () {
    final summary = SalesSummary.fromInvoices([
      // $10 sold when the rate was 15000, cost $6
      invoice(id: 1, currency: Currency.usd, rate: 15000, total: 1000, cost: 600),
      // $10 sold later when the rate was 16000, cost $6
      invoice(id: 2, currency: Currency.usd, rate: 16000, total: 1000, cost: 600),
      // 30,000 SYP sale with 20,000 cost
      invoice(id: 3, currency: Currency.syp, rate: 16000, total: 30000, cost: 20000),
    ], Currency.syp);

    expect(summary.count, 3);
    expect(summary.totalsByCurrency[Currency.usd], 2000);
    expect(summary.totalsByCurrency[Currency.syp], 30000);
    // 150,000 + 160,000 + 30,000, not 2 * today's rate
    expect(summary.totalInBase, 340000);
    // profit: 60,000 + 64,000 + 10,000
    expect(summary.profitInBase, 134000);
  });

  test('voided invoices are counted but not added', () {
    final summary = SalesSummary.fromInvoices([
      invoice(id: 1, currency: Currency.syp, rate: 15000, total: 5000, cost: 3000),
      invoice(
        id: 2,
        currency: Currency.syp,
        rate: 15000,
        total: 99999,
        cost: 1,
        status: InvoiceStatus.voided,
      ),
    ], Currency.syp);
    expect(summary.count, 1);
    expect(summary.voidedCount, 1);
    expect(summary.totalInBase, 5000);
    expect(summary.totalsByCurrency[Currency.syp], 5000);
  });

  test('a USD base currency converts SYP invoices back to dollars', () {
    final summary = SalesSummary.fromInvoices([
      invoice(id: 1, currency: Currency.syp, rate: 15000, total: 150000, cost: 90000),
    ], Currency.usd);
    expect(summary.totalInBase, 1000);
    expect(summary.profitInBase, 400);
  });

  test('no invoices gives zeros', () {
    final summary = SalesSummary.fromInvoices(const [], Currency.syp);
    expect(summary.count, 0);
    expect(summary.totalInBase, 0);
    expect(summary.totalsByCurrency, isEmpty);
  });
}
