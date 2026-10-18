import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
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

  setUpAll(sqfliteFfiInit);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dukan_customer_test_');
    appDb = AppDatabase.forTesting(
      path: p.join(tmp.path, 'test.db'),
      factory: databaseFactoryFfi,
    );
    customers = CustomerRepository(appDb);
    payments = CustomerPaymentRepository(appDb);
    sales = TransactionRepository(appDb);
    products = ProductRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
    tmp.deleteSync(recursive: true);
  });

  /// A credit sale of [total] SYP to [customerId], with [paid] paid now.
  Future<int> creditSale(int customerId, {int total = 100000, int paid = 0}) async {
    final productId = await products.create(const ProductInput(
      name: 'منتج',
      salePrice: 1,
      initialQuantity: 100,
    ));
    return sales.checkout(CheckoutRequest(
      currency: Currency.syp,
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

  group('create / list / update', () {
    test('lists customers sorted by name', () async {
      await customers.create(const CustomerInput(name: 'يوسف'));
      await customers.create(const CustomerInput(name: 'أحمد'));
      expect((await customers.list()).map((c) => c.name), ['أحمد', 'يوسف']);
    });

    test('a blank name is rejected', () async {
      await expectLater(
        customers.create(const CustomerInput(name: '   ')),
        _appError(AppError.invalidName),
      );
    });

    test('the phone is cleaned and an empty phone becomes null', () async {
      final a = await customers.create(
        const CustomerInput(name: 'أ', phone: ' ٠٩٣٣١٢٣٤٥٦ ', notes: '  ملاحظة '),
      );
      final b = await customers.create(const CustomerInput(name: 'ب', phone: '  '));
      final first = (await customers.getById(a))!;
      expect(first.phone, '0933123456');
      expect(first.notes, 'ملاحظة');
      expect((await customers.getById(b))!.phone, isNull);
      expect(first.isActive, isTrue);
    });

    test('duplicate names are allowed', () async {
      await customers.create(const CustomerInput(name: 'محمد'));
      await customers.create(const CustomerInput(name: 'محمد'));
      expect(await customers.list(), hasLength(2));
    });

    test('update changes the fields; a missing customer reports notFound', () async {
      final id = await customers.create(const CustomerInput(name: 'قديم'));
      await customers.update(id, const CustomerInput(name: 'جديد', phone: '123'));
      final updated = (await customers.getById(id))!;
      expect(updated.name, 'جديد');
      expect(updated.phone, '123');

      await expectLater(
        customers.update(999, const CustomerInput(name: 'x')),
        _appError(AppError.notFound),
      );
    });
  });

  group('search', () {
    test('ignores Arabic spelling variations and matches the phone', () async {
      await customers.create(const CustomerInput(name: 'أحمد علي', phone: '0933111222'));
      await customers.create(const CustomerInput(name: 'سامر', phone: '0944555666'));

      expect((await customers.list(query: 'احمد')).map((c) => c.name), ['أحمد علي']);
      expect((await customers.list(query: 'احمد علي')), hasLength(1));
      expect((await customers.list(query: '0944')).map((c) => c.name), ['سامر']);
      expect((await customers.list(query: '٠٩٤٤')).map((c) => c.name), ['سامر']);
      expect(await customers.list(query: 'غير موجود'), isEmpty);
    });
  });

  group('balances', () {
    test('a credit sale creates a debt; paid-now reduces it', () async {
      final id = await customers.create(const CustomerInput(name: 'زبون'));
      await creditSale(id, total: 100000, paid: 20000);

      final balance = await customers.balanceOf(id);
      expect(balance.of(Currency.syp), 80000);
      expect(balance.of(Currency.usd), 0);
      expect(balance.owes, isTrue);

      final listed = (await customers.listWithBalances()).single;
      expect(listed.balance.of(Currency.syp), 80000);
    });

    test('a customer without sales has a zero balance', () async {
      final id = await customers.create(const CustomerInput(name: 'زبون'));
      final balance = await customers.balanceOf(id);
      expect(balance.isZero, isTrue);
      expect(balance.owes, isFalse);
    });

    test('a voided credit invoice no longer counts', () async {
      final id = await customers.create(const CustomerInput(name: 'زبون'));
      final invoiceId = await creditSale(id, total: 50000);
      await sales.voidInvoice(invoiceId);
      expect((await customers.balanceOf(id)).isZero, isTrue);
    });

    test('owedIn converts the debts to one currency', () async {
      final id = await customers.create(const CustomerInput(name: 'زبون'));
      await creditSale(id, total: 30000);
      final balance = await customers.balanceOf(id);
      expect(balance.owedIn(Currency.syp, 15000), 30000);
      expect(balance.owedIn(Currency.usd, 15000), 200); // 2.00 USD
    });
  });

  group('hiding', () {
    test('a customer with a debt cannot be hidden', () async {
      final id = await customers.create(const CustomerInput(name: 'زبون'));
      await creditSale(id, total: 40000);
      await expectLater(customers.setActive(id, false), _appError(AppError.customerHasDebt));
      expect(await customers.list(), hasLength(1));
    });

    test('once the debt is paid the customer can be hidden and shown again', () async {
      final id = await customers.create(const CustomerInput(name: 'زبون'));
      await creditSale(id, total: 40000);
      await payments.addPayment(
        customerId: id,
        amount: 40000,
        currency: Currency.syp,
        appliedCurrency: Currency.syp,
        rate: 15000,
      );

      await customers.setActive(id, false);
      expect(await customers.list(), isEmpty);
      expect(await customers.list(includeInactive: true), hasLength(1));

      await customers.setActive(id, true);
      expect(await customers.list(), hasLength(1));
    });

    test('a missing customer reports notFound', () async {
      await expectLater(customers.setActive(999, true), _appError(AppError.notFound));
    });
  });
}
