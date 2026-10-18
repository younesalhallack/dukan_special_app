import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/core/currency/payment_math.dart';
import 'package:dukan_special_app/core/database/app_database.dart';
import 'package:dukan_special_app/core/errors/app_exceptions.dart';
import 'package:dukan_special_app/data/models/checkout_request.dart';
import 'package:dukan_special_app/data/models/customer.dart';
import 'package:dukan_special_app/data/models/product.dart';
import 'package:dukan_special_app/data/models/sale_transaction.dart';
import 'package:dukan_special_app/data/repositories/customer_payment_repository.dart';
import 'package:dukan_special_app/data/repositories/customer_repository.dart';
import 'package:dukan_special_app/data/repositories/product_repository.dart';
import 'package:dukan_special_app/data/repositories/transaction_repository.dart';

Matcher _appError(AppError error) => throwsA(
      isA<AppException>().having((e) => e.error, 'error', error),
    );

void main() {
  late Directory tmp;
  late AppDatabase appDb;
  late CustomerRepository customers;
  late CustomerPaymentRepository payments;
  late TransactionRepository sales;
  late ProductRepository products;
  late int customerId;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('dukan_payment_test_');
    appDb = AppDatabase.forTesting(
      path: p.join(tmp.path, 'test.db'),
      factory: databaseFactoryFfi,
    );
    customers = CustomerRepository(appDb);
    payments = CustomerPaymentRepository(appDb);
    sales = TransactionRepository(appDb);
    products = ProductRepository(appDb);
    customerId = await customers.create(const CustomerInput(name: 'زبون'));
  });

  tearDown(() async {
    await appDb.close();
    tmp.deleteSync(recursive: true);
  });

  Future<int> creditSale({
    Currency currency = Currency.syp,
    int total = 100000,
    int paid = 0,
  }) async {
    final productId = await products.create(const ProductInput(
      name: 'منتج',
      salePrice: 1,
      initialQuantity: 100,
    ));
    return sales.checkout(CheckoutRequest(
      currency: currency,
      exchangeRate: 15000,
      lines: [
        CheckoutLine(
          productId: productId,
          productName: 'منتج',
          quantity: 1,
          unitPrice: total,
          unitCost: 0,
          lineTotal: total,
        ),
      ],
      paymentType: PaymentType.credit,
      customerId: customerId,
      paidAmount: paid,
    ));
  }

  Future<int> balance(Currency currency) async =>
      (await customers.balanceOf(customerId)).of(currency);

  Future<int> pay(
    int amount, {
    Currency currency = Currency.syp,
    Currency applied = Currency.syp,
    double rate = 15000,
    String? note,
  }) {
    return payments.addPayment(
      customerId: customerId,
      amount: amount,
      currency: currency,
      appliedCurrency: applied,
      rate: rate,
      note: note,
    );
  }

  group('addPayment', () {
    test('a partial payment in the debt currency reduces the balance', () async {
      await creditSale(total: 100000);
      await pay(30000, note: '  دفعة أولى ');

      expect(await balance(Currency.syp), 70000);
      final saved = (await payments.listForCustomer(customerId)).single;
      expect(saved.amount, 30000);
      expect(saved.currency, Currency.syp);
      expect(saved.appliedAmount, 30000);
      expect(saved.appliedCurrency, Currency.syp);
      expect(saved.exchangeRate, 15000);
      expect(saved.note, 'دفعة أولى');
      expect(saved.isVoided, isFalse);
    });

    test('paying pounds against a dollar debt converts at the payment rate', () async {
      await creditSale(currency: Currency.usd, total: 1000); // $10.00
      await pay(75000, currency: Currency.syp, applied: Currency.usd);

      expect(await balance(Currency.usd), 500);
      final saved = (await payments.listForCustomer(customerId)).single;
      expect(saved.amount, 75000);
      expect(saved.currency, Currency.syp);
      expect(saved.appliedAmount, 500);
      expect(saved.appliedCurrency, Currency.usd);

      // The rest, using the "pay all" amount, closes the debt.
      final rest = PaymentMath.settlementAmount(
        balance: 500,
        payCurrency: Currency.syp,
        appliedCurrency: Currency.usd,
        rate: 15000,
      );
      await pay(rest, currency: Currency.syp, applied: Currency.usd);
      expect(await balance(Currency.usd), 0);
    });

    test('a payment above the debt is rejected and nothing is saved', () async {
      await creditSale(total: 50000);
      await expectLater(pay(50001), _appError(AppError.paymentExceedsDebt));
      expect(await payments.listForCustomer(customerId), isEmpty);
      expect(await balance(Currency.syp), 50000);
    });

    test('a rounding excess of a cross-currency payment is clamped to the debt', () async {
      await creditSale(total: 150000); // SYP debt
      // 979 cents at 15333 is 150,110 SYP: a little over, but within a cent.
      await pay(979, currency: Currency.usd, applied: Currency.syp, rate: 15333);
      expect(await balance(Currency.syp), 0);
      expect((await payments.listForCustomer(customerId)).single.appliedAmount, 150000);
    });

    test('there must be a debt in the chosen currency', () async {
      await creditSale(total: 50000); // only an SYP debt
      await expectLater(
        pay(100, currency: Currency.usd, applied: Currency.usd),
        _appError(AppError.noDebt),
      );
    });

    test('invalid input', () async {
      await creditSale();
      await expectLater(pay(0), _appError(AppError.invalidAmount));
      await expectLater(pay(-5), _appError(AppError.invalidAmount));
      await expectLater(pay(1000, rate: 0), _appError(AppError.invalidAmount));
      await expectLater(
        payments.addPayment(
          customerId: 999,
          amount: 100,
          currency: Currency.syp,
          appliedCurrency: Currency.syp,
          rate: 15000,
        ),
        _appError(AppError.notFound),
      );
      expect(await payments.listForCustomer(customerId), isEmpty);
    });
  });

  group('balances with several invoices and currencies', () {
    test('each currency keeps its own balance', () async {
      await creditSale(total: 100000, paid: 20000);
      await creditSale(currency: Currency.usd, total: 2500);
      await pay(30000);

      expect(await balance(Currency.syp), 50000); // 80000 - 30000
      expect(await balance(Currency.usd), 2500);
    });
  });

  group('voidPayment', () {
    test('the debt returns, the payment stays listed as voided', () async {
      await creditSale(total: 100000);
      final id = await pay(40000);
      expect(await balance(Currency.syp), 60000);

      await payments.voidPayment(id);

      expect(await balance(Currency.syp), 100000);
      final listed = await payments.listForCustomer(customerId);
      expect(listed, hasLength(1));
      expect(listed.single.isVoided, isTrue);
    });

    test('cannot be voided twice; unknown payments report notFound', () async {
      await creditSale();
      final id = await pay(1000);
      await payments.voidPayment(id);
      await expectLater(payments.voidPayment(id), _appError(AppError.alreadyVoided));
      await expectLater(payments.voidPayment(999), _appError(AppError.notFound));
    });

    test('a voided payment can be entered again', () async {
      await creditSale(total: 10000);
      final id = await pay(10000);
      await payments.voidPayment(id);
      await pay(10000);
      expect(await balance(Currency.syp), 0);
    });
  });

  group('voiding a credit invoice that was already paid', () {
    test('leaves a credit balance in the customer favour', () async {
      final invoiceId = await creditSale(total: 100000);
      await pay(100000);
      expect(await balance(Currency.syp), 0);

      await sales.voidInvoice(invoiceId);

      final result = await customers.balanceOf(customerId);
      expect(result.of(Currency.syp), -100000);
      expect(result.hasCredit, isTrue);
      expect(result.owes, isFalse);
      // A customer with a credit balance cannot be hidden either.
      await expectLater(
        customers.setActive(customerId, false),
        _appError(AppError.customerHasDebt),
      );
    });
  });

  group('listForCustomer', () {
    test('newest first and only this customer', () async {
      final other = await customers.create(const CustomerInput(name: 'آخر'));
      await creditSale(total: 100000);
      final first = await pay(1000);
      final second = await pay(2000);

      // a payment of another customer must not appear
      expect(await payments.listForCustomer(other), isEmpty);
      final listed = await payments.listForCustomer(customerId);
      expect(listed.map((e) => e.id), [second, first]);
    });
  });
}
