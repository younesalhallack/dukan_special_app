import 'package:flutter_test/flutter_test.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/data/models/customer_payment.dart';
import 'package:dukan_special_app/data/models/sale_transaction.dart';
import 'package:dukan_special_app/features/customers/logic/ledger_builder.dart';

SaleTransaction invoice({
  required int id,
  required String at,
  Currency currency = Currency.syp,
  int total = 100000,
  int paid = 0,
  PaymentType type = PaymentType.credit,
  InvoiceStatus status = InvoiceStatus.completed,
}) {
  return SaleTransaction(
    id: id,
    invoiceNumber: 'INV-$id',
    customerId: 1,
    currency: currency,
    exchangeRate: 15000,
    totalAmount: total,
    discountAmount: 0,
    paidAmount: paid,
    totalCost: 0,
    paymentType: type,
    status: status,
    note: null,
    createdAt: at,
  );
}

CustomerPayment payment({
  required int id,
  required String at,
  Currency currency = Currency.syp,
  int amount = 30000,
  Currency? appliedCurrency,
  int? applied,
  bool voided = false,
}) {
  return CustomerPayment(
    id: id,
    customerId: 1,
    transactionId: null,
    amount: amount,
    currency: currency,
    exchangeRate: 15000,
    appliedAmount: applied ?? amount,
    appliedCurrency: appliedCurrency ?? currency,
    note: null,
    createdAt: at,
    isVoided: voided,
  );
}

void main() {
  test('running balances per currency, oldest first', () {
    final entries = LedgerBuilder.build(
      invoices: [
        invoice(id: 1, at: '2026-10-01T10:00:00.000Z', total: 100000, paid: 20000),
        invoice(id: 2, at: '2026-10-03T10:00:00.000Z', currency: Currency.usd, total: 1000),
      ],
      payments: [
        payment(id: 1, at: '2026-10-02T10:00:00.000Z', amount: 30000),
      ],
    );

    expect(entries, hasLength(3));
    expect(entries[0].kind, LedgerEntryKind.invoice);
    expect(entries[0].delta, 80000); // total - paid at sale
    expect(entries[0].balanceAfter, 80000);

    expect(entries[1].kind, LedgerEntryKind.payment);
    expect(entries[1].delta, -30000);
    expect(entries[1].balanceAfter, 50000);

    // The dollar debt has its own running balance.
    expect(entries[2].currency, Currency.usd);
    expect(entries[2].balanceAfter, 1000);
  });

  test('a payment in another currency reduces the debt it was applied to', () {
    final entries = LedgerBuilder.build(
      invoices: [
        invoice(id: 1, at: '2026-10-01T10:00:00.000Z', currency: Currency.usd, total: 1000),
      ],
      payments: [
        payment(
          id: 1,
          at: '2026-10-02T10:00:00.000Z',
          currency: Currency.syp,
          amount: 75000,
          appliedCurrency: Currency.usd,
          applied: 500,
        ),
      ],
    );
    expect(entries[1].currency, Currency.usd);
    expect(entries[1].delta, -500);
    expect(entries[1].balanceAfter, 500);
  });

  test('voided entries are listed but do not count', () {
    final entries = LedgerBuilder.build(
      invoices: [
        invoice(id: 1, at: '2026-10-01T10:00:00.000Z', total: 100000),
        invoice(
          id: 2,
          at: '2026-10-02T10:00:00.000Z',
          total: 999999,
          status: InvoiceStatus.voided,
        ),
      ],
      payments: [
        payment(id: 1, at: '2026-10-03T10:00:00.000Z', amount: 40000, voided: true),
        payment(id: 2, at: '2026-10-04T10:00:00.000Z', amount: 10000),
      ],
    );

    expect(entries, hasLength(4));
    expect(entries[1].isVoided, isTrue);
    expect(entries[1].balanceAfter, isNull);
    expect(entries[2].isVoided, isTrue);
    expect(entries[2].balanceAfter, isNull);
    expect(entries[3].balanceAfter, 90000); // 100000 - 10000
  });

  test('cash invoices are not part of the statement', () {
    final entries = LedgerBuilder.build(
      invoices: [
        invoice(id: 1, at: '2026-10-01T10:00:00.000Z', type: PaymentType.cash, paid: 100000),
        invoice(id: 2, at: '2026-10-02T10:00:00.000Z', total: 5000),
      ],
      payments: const [],
    );
    expect(entries, hasLength(1));
    expect(entries.single.invoice!.id, 2);
  });

  test('at the same instant an invoice comes before a payment', () {
    final entries = LedgerBuilder.build(
      invoices: [invoice(id: 5, at: '2026-10-01T10:00:00.000Z', total: 1000)],
      payments: [payment(id: 1, at: '2026-10-01T10:00:00.000Z', amount: 1000)],
    );
    expect(entries.map((e) => e.kind), [LedgerEntryKind.invoice, LedgerEntryKind.payment]);
    expect(entries.last.balanceAfter, 0);
  });

  test('an invoice fully paid at the sale leaves the balance unchanged', () {
    final entries = LedgerBuilder.build(
      invoices: [invoice(id: 1, at: '2026-10-01T10:00:00.000Z', total: 5000, paid: 5000)],
      payments: const [],
    );
    expect(entries.single.delta, 0);
    expect(entries.single.balanceAfter, 0);
  });

  test('nothing gives an empty statement', () {
    expect(LedgerBuilder.build(invoices: const [], payments: const []), isEmpty);
  });
}
