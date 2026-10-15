import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/core/database/app_database.dart';
import 'package:dukan_special_app/core/database/schema.dart';
import 'package:dukan_special_app/core/errors/app_exceptions.dart';
import 'package:dukan_special_app/data/models/checkout_request.dart';
import 'package:dukan_special_app/data/models/product.dart';
import 'package:dukan_special_app/data/models/sale_transaction.dart';
import 'package:dukan_special_app/data/models/stock_movement.dart';
import 'package:dukan_special_app/data/repositories/product_repository.dart';
import 'package:dukan_special_app/data/repositories/settings_repository.dart';
import 'package:dukan_special_app/data/repositories/transaction_repository.dart';

Matcher _appError(AppError error) => throwsA(
      isA<AppException>().having((e) => e.error, 'error', error),
    );

void main() {
  late Directory tmp;
  late AppDatabase appDb;
  late ProductRepository products;
  late TransactionRepository sales;
  late SettingsRepository settings;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dukan_sales_test_');
    appDb = AppDatabase.forTesting(
      path: p.join(tmp.path, 'test.db'),
      factory: databaseFactoryFfi,
    );
    products = ProductRepository(appDb);
    sales = TransactionRepository(appDb);
    settings = SettingsRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
    tmp.deleteSync(recursive: true);
  });

  Future<int> addProduct(String name, {double quantity = 10}) {
    return products.create(ProductInput(
      name: name,
      salePrice: 1000,
      costPrice: 600,
      initialQuantity: quantity,
    ));
  }

  CheckoutLine lineFor(
    int productId, {
    double quantity = 1,
    int unitPrice = 150000,
    int unitCost = 90000,
  }) {
    return CheckoutLine(
      productId: productId,
      productName: 'product $productId',
      quantity: quantity,
      unitPrice: unitPrice,
      unitCost: unitCost,
      lineTotal: (unitPrice * quantity).round(),
    );
  }

  CheckoutRequest request(
    List<CheckoutLine> lines, {
    double rate = 15000,
    int discount = 0,
    PaymentType type = PaymentType.cash,
    int? paid,
    int? customerId,
  }) {
    return CheckoutRequest(
      currency: Currency.syp,
      exchangeRate: rate,
      lines: lines,
      discountAmount: discount,
      paymentType: type,
      paidAmount: paid,
      customerId: customerId,
    );
  }

  Future<int> countRows(String table) async {
    final db = await appDb.database;
    return (await db.query(table)).length;
  }

  group('checkout', () {
    test('saves the invoice with the frozen rate, items, stock and movements', () async {
      final a = await addProduct('A', quantity: 10);
      final b = await addProduct('B', quantity: 5);

      final id = await sales.checkout(request(
        [lineFor(a, quantity: 2), lineFor(b)],
        rate: 15250.5,
        discount: 10000,
      ));

      final details = (await sales.getWithItems(id))!;
      final tx = details.transaction;
      expect(tx.invoiceNumber, 'INV-000001');
      expect(tx.currency, Currency.syp);
      expect(tx.exchangeRate, 15250.5);
      expect(tx.subtotal, 450000);
      expect(tx.discountAmount, 10000);
      expect(tx.totalAmount, 440000);
      expect(tx.paidAmount, 440000); // cash sales are fully paid
      expect(tx.totalCost, 270000);
      expect(tx.profit, 170000);
      expect(tx.paymentType, PaymentType.cash);
      expect(tx.status, InvoiceStatus.completed);
      expect(details.items, hasLength(2));
      expect(details.items.first.quantity, 2);
      expect(details.items.first.lineTotal, 300000);

      expect((await products.getById(a))!.quantity, 8);
      expect((await products.getById(b))!.quantity, 4);

      final moves = await products.movementsFor(a);
      expect(moves.first.reason, StockReasons.sale);
      expect(moves.first.changeQty, -2);
      expect(moves.first.refTransactionId, id);
    });

    test('invoice numbers are sequential', () async {
      final a = await addProduct('A');
      final one = await sales.checkout(request([lineFor(a)]));
      final two = await sales.checkout(request([lineFor(a)]));
      expect((await sales.getWithItems(one))!.transaction.invoiceNumber, 'INV-000001');
      expect((await sales.getWithItems(two))!.transaction.invoiceNumber, 'INV-000002');
    });

    test('the stored rate does not change when the exchange rate changes later', () async {
      await settings.completeSetup(
        baseCurrency: Currency.syp,
        exchangeRate: 15000,
        sypRoundingStep: 100,
      );
      final a = await addProduct('A');
      final id = await sales.checkout(request([lineFor(a)], rate: 15000));

      await settings.updateExchangeRate(16000);

      expect((await sales.getWithItems(id))!.transaction.exchangeRate, 15000);
    });

    test('is atomic: a failure leaves no invoice, stock change or number used', () async {
      final a = await addProduct('A', quantity: 10);

      await expectLater(
        sales.checkout(request([lineFor(a, quantity: 2), lineFor(999)])),
        _appError(AppError.notFound),
      );

      expect(await countRows(Tables.transactions), 0);
      expect(await countRows(Tables.transactionItems), 0);
      expect((await products.getById(a))!.quantity, 10);
      // Only the opening-stock movement exists.
      expect(await products.movementsFor(a), hasLength(1));

      // The invoice number was not consumed by the failed attempt.
      final id = await sales.checkout(request([lineFor(a)]));
      expect((await sales.getWithItems(id))!.transaction.invoiceNumber, 'INV-000001');
    });

    test('selling more than the stock is allowed by default (stock goes negative)', () async {
      final a = await addProduct('A', quantity: 2);
      await sales.checkout(request([lineFor(a, quantity: 3)]));
      expect((await products.getById(a))!.quantity, -1);
    });

    test('with allow_negative_stock off, an oversell is rejected and nothing changes', () async {
      await settings.setAllowNegativeStock(false);
      final a = await addProduct('A', quantity: 2);

      await expectLater(
        sales.checkout(request([lineFor(a, quantity: 3)])),
        _appError(AppError.insufficientStock),
      );
      expect((await products.getById(a))!.quantity, 2);
      expect(await countRows(Tables.transactions), 0);

      // Exactly the available stock is fine.
      await sales.checkout(request([lineFor(a, quantity: 2)]));
      expect((await products.getById(a))!.quantity, 0);
    });

    test('the stock check adds up the same product on several lines', () async {
      await settings.setAllowNegativeStock(false);
      final a = await addProduct('A', quantity: 3);
      await expectLater(
        sales.checkout(request([lineFor(a, quantity: 2), lineFor(a, quantity: 2)])),
        _appError(AppError.insufficientStock),
      );
    });

    test('fractional quantities are stored exactly', () async {
      final a = await addProduct('A', quantity: 0.3);
      await sales.checkout(request([lineFor(a, quantity: 0.1)]));
      await sales.checkout(request([lineFor(a, quantity: 0.2)]));
      expect((await products.getById(a))!.quantity, 0);
    });

    test('validation errors', () async {
      final a = await addProduct('A');
      await expectLater(sales.checkout(request([])), _appError(AppError.emptyCart));
      await expectLater(
        sales.checkout(request([lineFor(a)], rate: 0)),
        _appError(AppError.invalidAmount),
      );
      await expectLater(
        sales.checkout(request([lineFor(a)], discount: 150001)),
        _appError(AppError.invalidAmount),
      );
      await expectLater(
        sales.checkout(request([lineFor(a)], discount: -1)),
        _appError(AppError.invalidAmount),
      );
      await expectLater(
        sales.checkout(request([lineFor(a, quantity: 0)])),
        _appError(AppError.invalidAmount),
      );
      expect(await countRows(Tables.transactions), 0);
    });

    test('credit sales need a customer and record the partial payment', () async {
      final a = await addProduct('A');
      await expectLater(
        sales.checkout(request([lineFor(a)], type: PaymentType.credit)),
        _appError(AppError.customerRequired),
      );

      final db = await appDb.database;
      final customerId = await db.insert(Tables.customers, {
        'name': 'زبون',
        'name_normalized': 'زبون',
        'created_at': '2026-10-14T00:00:00.000Z',
      });

      await expectLater(
        sales.checkout(request(
          [lineFor(a)],
          type: PaymentType.credit,
          customerId: customerId,
          paid: 150001,
        )),
        _appError(AppError.invalidAmount),
      );

      final id = await sales.checkout(request(
        [lineFor(a)],
        type: PaymentType.credit,
        customerId: customerId,
        paid: 50000,
      ));
      final tx = (await sales.getWithItems(id))!.transaction;
      expect(tx.paymentType, PaymentType.credit);
      expect(tx.customerId, customerId);
      expect(tx.paidAmount, 50000);
      expect(tx.debtAmount, 100000);
    });
  });

  group('list / getWithItems', () {
    test('newest first, filters by date range and voided status', () async {
      final a = await addProduct('A');
      final first = await sales.checkout(request([lineFor(a)]));
      final second = await sales.checkout(request([lineFor(a)]));
      await sales.voidInvoice(first);

      final all = await sales.list();
      expect(all.map((t) => t.id), [second, first]);

      final active = await sales.list(includeVoided: false);
      expect(active.map((t) => t.id), [second]);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      expect(await sales.list(from: today, to: tomorrow), hasLength(2));
      expect(
        await sales.list(from: tomorrow, to: tomorrow.add(const Duration(days: 1))),
        isEmpty,
      );
      expect(
        await sales.list(
          from: today.subtract(const Duration(days: 1)),
          to: today,
        ),
        isEmpty,
      );
    });

    test('getWithItems returns null for an unknown invoice', () async {
      expect(await sales.getWithItems(999), isNull);
    });
  });

  group('voidInvoice', () {
    test('restores the stock, logs void movements and keeps the invoice', () async {
      final a = await addProduct('A', quantity: 10);
      final id = await sales.checkout(request([lineFor(a, quantity: 4)]));
      expect((await products.getById(a))!.quantity, 6);

      await sales.voidInvoice(id);

      expect((await products.getById(a))!.quantity, 10);
      final tx = (await sales.getWithItems(id))!.transaction;
      expect(tx.status, InvoiceStatus.voided);
      expect(tx.isVoided, isTrue);

      final moves = await products.movementsFor(a);
      expect(moves.first.reason, StockReasons.voidSale);
      expect(moves.first.changeQty, 4);
      expect(moves.first.refTransactionId, id);
    });

    test('cannot be voided twice, and unknown invoices report notFound', () async {
      final a = await addProduct('A');
      final id = await sales.checkout(request([lineFor(a)]));
      await sales.voidInvoice(id);
      await expectLater(sales.voidInvoice(id), _appError(AppError.alreadyVoided));
      await expectLater(sales.voidInvoice(999), _appError(AppError.notFound));
      // The failed second attempt did not restore the stock again.
      expect((await products.getById(a))!.quantity, 10);
    });
  });
}
