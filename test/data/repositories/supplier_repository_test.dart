import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/core/database/app_database.dart';
import 'package:dukan_special_app/core/errors/app_exceptions.dart';
import 'package:dukan_special_app/data/models/product.dart';
import 'package:dukan_special_app/data/models/purchase_request.dart';
import 'package:dukan_special_app/data/models/sale_transaction.dart';
import 'package:dukan_special_app/data/models/supplier.dart';
import 'package:dukan_special_app/data/repositories/product_repository.dart';
import 'package:dukan_special_app/data/repositories/purchase_repository.dart';
import 'package:dukan_special_app/data/repositories/supplier_payment_repository.dart';
import 'package:dukan_special_app/data/repositories/supplier_repository.dart';

Matcher _appError(AppError error) => throwsA(
      isA<AppException>().having((e) => e.error, 'error', error),
    );

void main() {
  late Directory tmp;
  late AppDatabase appDb;
  late SupplierRepository suppliers;
  late SupplierPaymentRepository payments;
  late PurchaseRepository purchases;
  late ProductRepository products;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dukan_supplier_test_');
    appDb = AppDatabase.forTesting(
      path: p.join(tmp.path, 'test.db'),
      factory: databaseFactoryFfi,
    );
    suppliers = SupplierRepository(appDb);
    payments = SupplierPaymentRepository(appDb);
    purchases = PurchaseRepository(appDb);
    products = ProductRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
    tmp.deleteSync(recursive: true);
  });

  /// A credit purchase of [total] SYP from [supplierId], with [paid] paid now.
  Future<int> creditPurchase(int supplierId, {int total = 100000, int paid = 0}) async {
    final productId = await products.create(const ProductInput(
      name: 'منتج',
      salePrice: 1,
      initialQuantity: 1,
    ));
    return purchases.create(PurchaseRequest(
      currency: Currency.syp,
      exchangeRate: 15000,
      lines: [
        PurchaseLine(
          productId: productId,
          productName: 'منتج',
          quantity: 1,
          unitCost: total,
          lineTotal: total,
        ),
      ],
      purchaseDate: DateTime(2026, 10, 14, 12),
      paymentType: PaymentType.credit,
      supplierId: supplierId,
      paidAmount: paid,
    ));
  }

  group('create / list / update', () {
    test('lists suppliers sorted by name', () async {
      await suppliers.create(const SupplierInput(name: 'يوسف'));
      await suppliers.create(const SupplierInput(name: 'أحمد'));
      expect((await suppliers.list()).map((s) => s.name), ['أحمد', 'يوسف']);
    });

    test('a blank name is rejected', () async {
      await expectLater(
        suppliers.create(const SupplierInput(name: '  ')),
        _appError(AppError.invalidName),
      );
    });

    test('the phone is cleaned and an empty phone becomes null', () async {
      final a = await suppliers.create(
        const SupplierInput(name: 'أ', phone: ' ٠٩٣٣١٢٣٤٥٦ ', notes: '  ملاحظة '),
      );
      final b = await suppliers.create(const SupplierInput(name: 'ب', phone: ' '));
      final first = (await suppliers.getById(a))!;
      expect(first.phone, '0933123456');
      expect(first.notes, 'ملاحظة');
      expect((await suppliers.getById(b))!.phone, isNull);
    });

    test('duplicate names are allowed', () async {
      await suppliers.create(const SupplierInput(name: 'شركة النور'));
      await suppliers.create(const SupplierInput(name: 'شركة النور'));
      expect(await suppliers.list(), hasLength(2));
    });

    test('update changes the fields; a missing supplier reports notFound', () async {
      final id = await suppliers.create(const SupplierInput(name: 'قديم'));
      await suppliers.update(id, const SupplierInput(name: 'جديد', phone: '123'));
      expect((await suppliers.getById(id))!.name, 'جديد');
      await expectLater(
        suppliers.update(999, const SupplierInput(name: 'x')),
        _appError(AppError.notFound),
      );
    });
  });

  test('search ignores Arabic spelling variations and matches the phone', () async {
    await suppliers.create(const SupplierInput(name: 'أحمد للتجارة', phone: '0933111222'));
    await suppliers.create(const SupplierInput(name: 'سامر', phone: '0944555666'));
    expect((await suppliers.list(query: 'احمد')).map((s) => s.name), ['أحمد للتجارة']);
    expect((await suppliers.list(query: '٠٩٤٤')).map((s) => s.name), ['سامر']);
    expect(await suppliers.list(query: 'غير موجود'), isEmpty);
  });

  group('balances', () {
    test('a credit purchase creates a debt; paid-now reduces it', () async {
      final id = await suppliers.create(const SupplierInput(name: 'مورد'));
      await creditPurchase(id, total: 100000, paid: 20000);

      final balance = await suppliers.balanceOf(id);
      expect(balance.of(Currency.syp), 80000);
      expect(balance.of(Currency.usd), 0);
      expect(balance.owed, isTrue);
      expect((await suppliers.listWithBalances()).single.balance.of(Currency.syp), 80000);
    });

    test('a supplier without purchases has a zero balance', () async {
      final id = await suppliers.create(const SupplierInput(name: 'مورد'));
      expect((await suppliers.balanceOf(id)).isZero, isTrue);
    });

    test('a voided credit purchase no longer counts', () async {
      final id = await suppliers.create(const SupplierInput(name: 'مورد'));
      final purchaseId = await creditPurchase(id, total: 50000);
      await purchases.voidPurchase(purchaseId);
      expect((await suppliers.balanceOf(id)).isZero, isTrue);
    });

    test('owedIn converts what we owe to one currency', () async {
      final id = await suppliers.create(const SupplierInput(name: 'مورد'));
      await creditPurchase(id, total: 30000);
      final balance = await suppliers.balanceOf(id);
      expect(balance.owedIn(Currency.syp, 15000), 30000);
      expect(balance.owedIn(Currency.usd, 15000), 200);
    });
  });

  group('hiding', () {
    test('a supplier we owe cannot be hidden', () async {
      final id = await suppliers.create(const SupplierInput(name: 'مورد'));
      await creditPurchase(id, total: 40000);
      await expectLater(suppliers.setActive(id, false), _appError(AppError.supplierHasDebt));
      expect(await suppliers.list(), hasLength(1));
    });

    test('once paid in full the supplier can be hidden and shown again', () async {
      final id = await suppliers.create(const SupplierInput(name: 'مورد'));
      await creditPurchase(id, total: 40000);
      await payments.addPayment(
        supplierId: id,
        amount: 40000,
        currency: Currency.syp,
        appliedCurrency: Currency.syp,
        rate: 15000,
      );
      await suppliers.setActive(id, false);
      expect(await suppliers.list(), isEmpty);
      expect(await suppliers.list(includeInactive: true), hasLength(1));
      await suppliers.setActive(id, true);
      expect(await suppliers.list(), hasLength(1));
    });

    test('a missing supplier reports notFound', () async {
      await expectLater(suppliers.setActive(999, true), _appError(AppError.notFound));
    });
  });
}
