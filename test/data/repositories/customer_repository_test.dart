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

  /// A credit invoice of [total] SYP for [customerId], with [paid] paid now.
  Future<int> creditSale(int customerId, {int total = 100000, int paid = 0}) async {
    final productId = await products.create(
      const ProductInput(name: 'سلعة', salePrice: 1, initialQuantity: 100),
    );
    return sales.checkout(CheckoutRequest(
      currency: Currency.syp,
      exchangeRate: 15000,
      lines: [
        CheckoutLine(
          productId: productId,
          productName: 'سلعة',
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

  group('CRUD', () {
    test('create and list, sorted by name', () async {
      await customers.create(const CustomerInput(name: 'محمد'));
      await customers.create(const CustomerInput(name: 'أحمد'));
      final names = (await customers.list()).map((c) => c.name).toList();
      expect(names, ['أحمد', 'محمد']);
    });

    test('the name is required; phone and notes are cleaned', () async {
      await expectLater(
        customers.create(const CustomerInput(name: '   ')),
        _appError(AppError.invalidName),
      );
      final id = await customers.create(
        const CustomerInput(name: ' سامر ', phone: ' ٠٩٣٣١٢٣٤٥٦ ', notes: '  '),
      );
      final customer = (await customers.getById(id))!;
      expect(customer.name, 'سامر');
      expect(customer.phone, '0933123456');
      expect(customer.notes, isNull);
    });

    test('the same name may be used twice', () async {
      await customers.create(const CustomerInput(name: 'أحمد', phone: '1'));
      await customers.create(const CustomerInput(name: 'أحمد', phone: '2'));
      expect(await customers.list(), hasLength(2));
    });

    test('update changes the fields; a missing customer reports notFound', () async {
      final id = await customers.create(const CustomerInput(name: 'قديم'));
      await customers.update(id, const CustomerInput(name: 'جديد', phone: '55'));
      final customer = (await customers.getById(id))!;
      expect(customer.name, 'جديد');
      expect(customer.phone, '55');
      await expectLater(
        customers.update(999, const CustomerInput(name: 'x')),
        _appError(AppError.notFound),
      );
    });
  });

  group('search', () {
    test('ignores Arabic spelling variations and matches the phone', () async {
      await customers.create(const CustomerInput(name: 'أحمد خالد', phone: '0933111222'));
      await customers.create(const CustomerInput(name: 'ياسر', phone: '0944555666'));

      expect((await customers.list(query: 'احمد')).map((c) => c.name), ['أحمد خالد']);
      expect((await customers.list(query: 'احمد خالد')), hasLength(1));
      expect((await customers.list(query: '555666')).map((c) => c.name), ['ياسر']);
      expect(await customers.list(query: 'غير موجود'), isEmpty);
    });
  });

  group('balances', () {
    test('credit invoices create a debt, payments reduce it', () async {
      final id = await customers.create(const CustomerInput(name: 'أحمد'));
      await creditSale(id, total: 100000, paid: 20000);

      var item = (await customers.listWithBalances()).single;
      expect(item.balance.of(Currency.syp), 80000);
      expect(item.balance.of(Currency.usd), 0);
      expect(item.balance.owes, isTrue);

      await payments.addPayment(
        customerId: id,
        amount: 30000,
        currency: Currency.syp,
        appliedCurrency: Currency.syp,
        rate: 15000,
      );
      item = (await customers.listWithBalances()).single;
      expect(item.balance.of(Currency.syp), 50000);
    });

    test('a customer without invoices has a zero balance', () async {
      final id = await customers.create(const CustomerInput(name: 'جديد'));
      final balance = await customers.balanceOf(id);
      expect(balance.isZero, isTrue);
      expect(balance.owes, isFalse);
    });

    test('each customer has his own balance', () async {
      final a = await customers.create(const CustomerInput(name: 'أ'));
      final b = await customers.create(const CustomerInput(name: 'ب'));
      await creditSale(a, total: 1000);
      await creditSale(b, total: 7000);
      expect((await customers.balanceOf(a)).of(Currency.syp), 1000);
      expect((await customers.balanceOf(b)).of(Currency.syp), 7000);
    });

    test('a voided credit invoice is no longer owed', () async {
      final id = await customers.create(const CustomerInput(name: 'أحمد'));
      final invoiceId = await creditSale(id, total: 50000);
      await sales.voidInvoice(invoiceId);
      expect((await customers.balanceOf(id)).isZero, isTrue);
    });

    test('owedIn converts every debt to the base currency', () async {
      final id = await customers.create(const CustomerInput(name: 'أحمد'));
      await creditSale(id, total: 30000);
      final usdProduct = await products.create(
        const ProductInput(name: 'دولار', salePrice: 1, initialQuantity: 5),
      );
      await sales.checkout(CheckoutRequest(
        currency: Currency.usd,
        exchangeRate: 15000,
        lines: [
          CheckoutLine(
            productId: usdProduct,
            productName: 'دولار',
            quantity: 1,
            unitPrice: 1000,
            unitCost: 0,
            lineTotal: 1000,
          ),
        ],
        paymentType: PaymentType.credit,
        customerId: id,
        paidAmount: 0,
      ));
      final balance = await customers.balanceOf(id);
      expect(balance.of(Currency.usd), 1000);
      // 30,000 SYP + $10 at 15,000
      expect(balance.owedIn(Currency.syp, 15000), 30000 + 150000);
      // 30,000 SYP is $2.00 = 200 cents, plus the $10.00 debt
      expect(balance.owedIn(Currency.usd, 15000), 200 + 1000);
    });
  });

  group('hiding a customer', () {
    test('is refused while he owes something, allowed once settled', () async {
      final id = await customers.create(const CustomerInput(name: 'أحمد'));
      await creditSale(id, total: 10000);

      await expectLater(
        customers.setActive(id, false),
        _appError(AppError.customerHasDebt),
      );
      expect(await customers.list(), hasLength(1));

      await payments.addPayment(
        customerId: id,
        amount: 10000,
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
