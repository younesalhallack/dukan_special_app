import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/core/database/app_database.dart';
import 'package:dukan_special_app/core/database/schema.dart';
import 'package:dukan_special_app/core/errors/app_exceptions.dart';
import 'package:dukan_special_app/data/models/product.dart';
import 'package:dukan_special_app/data/models/purchase_request.dart';
import 'package:dukan_special_app/data/models/sale_transaction.dart';
import 'package:dukan_special_app/data/models/stock_movement.dart';
import 'package:dukan_special_app/data/models/supplier.dart';
import 'package:dukan_special_app/data/repositories/product_repository.dart';
import 'package:dukan_special_app/data/repositories/purchase_repository.dart';
import 'package:dukan_special_app/data/repositories/supplier_repository.dart';

Matcher _appError(AppError error) => throwsA(
      isA<AppException>().having((e) => e.error, 'error', error),
    );

void main() {
  late Directory tmp;
  late AppDatabase appDb;
  late ProductRepository products;
  late PurchaseRepository purchases;
  late SupplierRepository suppliers;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dukan_purchase_test_');
    appDb = AppDatabase.forTesting(
      path: p.join(tmp.path, 'test.db'),
      factory: databaseFactoryFfi,
    );
    products = ProductRepository(appDb);
    purchases = PurchaseRepository(appDb);
    suppliers = SupplierRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
    tmp.deleteSync(recursive: true);
  });

  /// A product whose cost is $6.00 with [quantity] in stock.
  Future<int> addProduct(String name, {double quantity = 10}) {
    return products.create(ProductInput(
      name: name,
      salePrice: 1000,
      costPrice: 600,
      costCurrency: Currency.usd,
      initialQuantity: quantity,
    ));
  }

  PurchaseLine lineFor(int productId, {double quantity = 1, int unitCost = 700}) {
    return PurchaseLine(
      productId: productId,
      productName: 'product $productId',
      quantity: quantity,
      unitCost: unitCost,
      lineTotal: (unitCost * quantity).round(),
    );
  }

  PurchaseRequest request(
    List<PurchaseLine> lines, {
    Currency currency = Currency.usd,
    double rate = 15000,
    int discount = 0,
    PaymentType type = PaymentType.cash,
    int? paid,
    int? supplierId,
    String? invoiceNumber,
    bool updateCosts = true,
    DateTime? date,
  }) {
    return PurchaseRequest(
      currency: currency,
      exchangeRate: rate,
      lines: lines,
      purchaseDate: date ?? DateTime(2026, 10, 14, 12),
      discountAmount: discount,
      paymentType: type,
      paidAmount: paid,
      supplierId: supplierId,
      supplierInvoiceNumber: invoiceNumber,
      updateCosts: updateCosts,
    );
  }

  Future<int> countRows(String table) async {
    final db = await appDb.database;
    return (await db.query(table)).length;
  }

  group('create', () {
    test('saves the invoice, adds the stock, logs movements and updates the cost', () async {
      final a = await addProduct('A', quantity: 10);
      final b = await addProduct('B', quantity: 2);

      final id = await purchases.create(request(
        [lineFor(a, quantity: 5), lineFor(b, quantity: 3, unitCost: 250)],
        rate: 15250.5,
        discount: 100,
        invoiceNumber: '  FT-77 ',
      ));

      final details = (await purchases.getWithItems(id))!;
      final purchase = details.purchase;
      expect(purchase.purchaseNumber, 'PUR-000001');
      expect(purchase.supplierInvoiceNumber, 'FT-77');
      expect(purchase.currency, Currency.usd);
      expect(purchase.exchangeRate, 15250.5);
      expect(purchase.subtotal, 3500 + 750);
      expect(purchase.discountAmount, 100);
      expect(purchase.totalAmount, 4150);
      expect(purchase.paidAmount, 4150); // cash purchases are fully paid
      expect(purchase.paymentType, PaymentType.cash);
      expect(purchase.status, InvoiceStatus.completed);
      expect(purchase.supplierId, isNull);
      expect(details.items, hasLength(2));
      expect(details.items.first.quantity, 5);
      expect(details.items.first.lineTotal, 3500);

      expect((await products.getById(a))!.quantity, 15);
      expect((await products.getById(b))!.quantity, 5);
      expect((await products.getById(a))!.costPrice, 700);
      expect((await products.getById(b))!.costPrice, 250);

      final moves = await products.movementsFor(a);
      expect(moves.first.reason, StockReasons.restock);
      expect(moves.first.changeQty, 5);
      expect(moves.first.refPurchaseId, id);
      expect(moves.first.refTransactionId, isNull);
    });

    test('the unit cost is converted to the product cost currency at the invoice rate', () async {
      final a = await addProduct('A');
      // 105,000 SYP at 15000 is $7.00
      await purchases.create(request(
        [lineFor(a, unitCost: 105000)],
        currency: Currency.syp,
        rate: 15000,
      ));
      final product = (await products.getById(a))!;
      expect(product.costPrice, 700);
      expect(product.costCurrency, Currency.usd);
    });

    test('updateCosts off leaves the cost alone', () async {
      final a = await addProduct('A');
      await purchases.create(request([lineFor(a)], updateCosts: false));
      expect((await products.getById(a))!.costPrice, 600);
      expect((await products.getById(a))!.quantity, 11); // the stock still grows
    });

    test('a line without a cost does not change the product cost', () async {
      final a = await addProduct('A');
      await purchases.create(request([lineFor(a, unitCost: 0)]));
      expect((await products.getById(a))!.costPrice, 600);
    });

    test('purchase numbers are sequential', () async {
      final a = await addProduct('A');
      final one = await purchases.create(request([lineFor(a)]));
      final two = await purchases.create(request([lineFor(a)]));
      expect((await purchases.getWithItems(one))!.purchase.purchaseNumber, 'PUR-000001');
      expect((await purchases.getWithItems(two))!.purchase.purchaseNumber, 'PUR-000002');
    });

    test('is atomic: a failure leaves nothing behind and does not use a number', () async {
      final a = await addProduct('A', quantity: 10);
      await expectLater(
        purchases.create(request([lineFor(a, quantity: 2), lineFor(999)])),
        _appError(AppError.notFound),
      );
      expect(await countRows(Tables.purchases), 0);
      expect(await countRows(Tables.purchaseItems), 0);
      expect((await products.getById(a))!.quantity, 10);
      expect((await products.getById(a))!.costPrice, 600);
      expect(await products.movementsFor(a), hasLength(1)); // only the opening stock

      final id = await purchases.create(request([lineFor(a)]));
      expect((await purchases.getWithItems(id))!.purchase.purchaseNumber, 'PUR-000001');
    });

    test('validation errors', () async {
      final a = await addProduct('A');
      await expectLater(purchases.create(request([])), _appError(AppError.emptyPurchase));
      await expectLater(
        purchases.create(request([lineFor(a)], rate: 0)),
        _appError(AppError.invalidAmount),
      );
      await expectLater(
        purchases.create(request([lineFor(a)], discount: 701)),
        _appError(AppError.invalidAmount),
      );
      await expectLater(
        purchases.create(request([lineFor(a, quantity: 0)])),
        _appError(AppError.invalidAmount),
      );
      expect(await countRows(Tables.purchases), 0);
    });
  });

  group('credit purchases', () {
    test('need a supplier and record the part paid now', () async {
      final a = await addProduct('A');
      await expectLater(
        purchases.create(request([lineFor(a)], type: PaymentType.credit)),
        _appError(AppError.supplierRequired),
      );

      final supplierId = await suppliers.create(const SupplierInput(name: 'مورد'));
      await expectLater(
        purchases.create(request(
          [lineFor(a)],
          type: PaymentType.credit,
          supplierId: supplierId,
          paid: 701,
        )),
        _appError(AppError.invalidAmount),
      );

      final id = await purchases.create(request(
        [lineFor(a, quantity: 10)],
        type: PaymentType.credit,
        supplierId: supplierId,
        paid: 2000,
      ));
      final purchase = (await purchases.getWithItems(id))!.purchase;
      expect(purchase.paymentType, PaymentType.credit);
      expect(purchase.supplierId, supplierId);
      expect(purchase.totalAmount, 7000);
      expect(purchase.paidAmount, 2000);
      expect(purchase.debtAmount, 5000);
    });

    test('an unknown supplier reports notFound and saves nothing', () async {
      final a = await addProduct('A');
      await expectLater(
        purchases.create(request([lineFor(a)], supplierId: 999)),
        _appError(AppError.notFound),
      );
      expect(await countRows(Tables.purchases), 0);
    });
  });

  group('list / getWithItems', () {
    test('newest first, filters by date, supplier and voided status', () async {
      final a = await addProduct('A');
      final s1 = await suppliers.create(const SupplierInput(name: 'مورد 1'));
      final first = await purchases.create(request(
        [lineFor(a)],
        supplierId: s1,
        date: DateTime(2026, 10, 1, 12),
      ));
      final second = await purchases.create(request(
        [lineFor(a)],
        date: DateTime(2026, 10, 2, 12),
      ));
      await purchases.voidPurchase(first);

      expect((await purchases.list()).map((p) => p.id), [second, first]);
      expect((await purchases.list(includeVoided: false)).map((p) => p.id), [second]);
      expect((await purchases.list(supplierId: s1)).map((p) => p.id), [first]);
      expect(
        (await purchases.list(from: DateTime(2026, 10, 2), to: DateTime(2026, 10, 3)))
            .map((p) => p.id),
        [second],
      );
      expect(
        await purchases.list(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 2)),
        isEmpty,
      );
    });

    test('getWithItems returns null for an unknown purchase', () async {
      expect(await purchases.getWithItems(999), isNull);
    });
  });

  group('voidPurchase', () {
    test('takes the quantities out, logs void movements and keeps the purchase', () async {
      final a = await addProduct('A', quantity: 10);
      final id = await purchases.create(request([lineFor(a, quantity: 4)]));
      expect((await products.getById(a))!.quantity, 14);

      await purchases.voidPurchase(id);

      expect((await products.getById(a))!.quantity, 10);
      final purchase = (await purchases.getWithItems(id))!.purchase;
      expect(purchase.status, InvoiceStatus.voided);
      final moves = await products.movementsFor(a);
      expect(moves.first.reason, StockReasons.voidSale);
      expect(moves.first.changeQty, -4);
      expect(moves.first.refPurchaseId, id);
    });

    test('the stock may go below zero if the goods were already used', () async {
      final a = await addProduct('A', quantity: 0);
      final id = await purchases.create(request([lineFor(a, quantity: 5)]));
      await products.adjustStock(
        productId: a,
        delta: -5,
        reason: StockReasons.adjustment,
      );
      await purchases.voidPurchase(id);
      expect((await products.getById(a))!.quantity, -5);
    });

    test('does not restore the previous product cost', () async {
      final a = await addProduct('A');
      final id = await purchases.create(request([lineFor(a)]));
      await purchases.voidPurchase(id);
      expect((await products.getById(a))!.costPrice, 700);
    });

    test('cannot be voided twice; unknown purchases report notFound', () async {
      final a = await addProduct('A');
      final id = await purchases.create(request([lineFor(a)]));
      await purchases.voidPurchase(id);
      await expectLater(purchases.voidPurchase(id), _appError(AppError.alreadyVoided));
      await expectLater(purchases.voidPurchase(999), _appError(AppError.notFound));
      // The failed second attempt did not take the stock out again.
      expect((await products.getById(a))!.quantity, 10);
    });
  });
}
