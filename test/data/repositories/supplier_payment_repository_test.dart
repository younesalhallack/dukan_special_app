import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/core/currency/payment_math.dart';
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
  late int supplierId;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('dukan_supplier_payment_test_');
    appDb = AppDatabase.forTesting(
      path: p.join(tmp.path, 'test.db'),
      factory: databaseFactoryFfi,
    );
    suppliers = SupplierRepository(appDb);
    payments = SupplierPaymentRepository(appDb);
    purchases = PurchaseRepository(appDb);
    products = ProductRepository(appDb);
    supplierId = await suppliers.create(const SupplierInput(name: 'مورد'));
  });

  tearDown(() async {
    await appDb.close();
    tmp.deleteSync(recursive: true);
  });

  Future<int> creditPurchase({
    Currency currency = Currency.syp,
    int total = 100000,
    int paid = 0,
  }) async {
    final productId = await products.create(const ProductInput(
      name: 'منتج',
      salePrice: 1,
      initialQuantity: 1,
    ));
    return purchases.create(PurchaseRequest(
      currency: currency,
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

  Future<int> balance(Currency currency) async =>
      (await suppliers.balanceOf(supplierId)).of(currency);

  Future<int> pay(
    int amount, {
    Currency currency = Currency.syp,
    Currency applied = Currency.syp,
    double rate = 15000,
    String? note,
  }) {
    return payments.addPayment(
      supplierId: supplierId,
      amount: amount,
      currency: currency,
      appliedCurrency: applied,
      rate: rate,
      note: note,
    );
  }

  group('addPayment', () {
    test('a partial payment in the debt currency reduces the balance', () async {
      await creditPurchase(total: 100000);
      await pay(30000, note: '  دفعة ');

      expect(await balance(Currency.syp), 70000);
      final saved = (await payments.listForSupplier(supplierId)).single;
      expect(saved.amount, 30000);
      expect(saved.appliedAmount, 30000);
      expect(saved.appliedCurrency, Currency.syp);
      expect(saved.exchangeRate, 15000);
      expect(saved.note, 'دفعة');
      expect(saved.isVoided, isFalse);
    });

    test('paying pounds against a dollar debt converts at the payment rate', () async {
      await creditPurchase(currency: Currency.usd, total: 1000);
      await pay(75000, currency: Currency.syp, applied: Currency.usd);
      expect(await balance(Currency.usd), 500);

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
      await creditPurchase(total: 50000);
      await expectLater(pay(50001), _appError(AppError.paymentExceedsDebt));
      expect(await payments.listForSupplier(supplierId), isEmpty);
      expect(await balance(Currency.syp), 50000);
    });

    test('a rounding excess of a cross-currency payment is clamped to the debt', () async {
      await creditPurchase(total: 150000);
      await pay(979, currency: Currency.usd, applied: Currency.syp, rate: 15333);
      expect(await balance(Currency.syp), 0);
      expect((await payments.listForSupplier(supplierId)).single.appliedAmount, 150000);
    });

    test('there must be a debt in the chosen currency', () async {
      await creditPurchase(total: 50000); // only an SYP debt
      await expectLater(
        pay(100, currency: Currency.usd, applied: Currency.usd),
        _appError(AppError.noPayable),
      );
    });

    test('invalid input', () async {
      await creditPurchase();
      await expectLater(pay(0), _appError(AppError.invalidAmount));
      await expectLater(pay(-5), _appError(AppError.invalidAmount));
      await expectLater(pay(1000, rate: 0), _appError(AppError.invalidAmount));
      await expectLater(
        payments.addPayment(
          supplierId: 999,
          amount: 100,
          currency: Currency.syp,
          appliedCurrency: Currency.syp,
          rate: 15000,
        ),
        _appError(AppError.notFound),
      );
      expect(await payments.listForSupplier(supplierId), isEmpty);
    });
  });

  test('each currency keeps its own balance', () async {
    await creditPurchase(total: 100000, paid: 20000);
    await creditPurchase(currency: Currency.usd, total: 2500);
    await pay(30000);
    expect(await balance(Currency.syp), 50000);
    expect(await balance(Currency.usd), 2500);
  });

  group('voidPayment', () {
    test('the debt returns, the payment stays listed as voided', () async {
      await creditPurchase(total: 100000);
      final id = await pay(40000);
      expect(await balance(Currency.syp), 60000);

      await payments.voidPayment(id);

      expect(await balance(Currency.syp), 100000);
      final listed = await payments.listForSupplier(supplierId);
      expect(listed, hasLength(1));
      expect(listed.single.isVoided, isTrue);
    });

    test('cannot be voided twice; unknown payments report notFound', () async {
      await creditPurchase();
      final id = await pay(1000);
      await payments.voidPayment(id);
      await expectLater(payments.voidPayment(id), _appError(AppError.alreadyVoided));
      await expectLater(payments.voidPayment(999), _appError(AppError.notFound));
    });
  });

  test('voiding a credit purchase that was already paid leaves an advance with the supplier', () async {
    final purchaseId = await creditPurchase(total: 100000);
    await pay(100000);
    expect(await balance(Currency.syp), 0);

    await purchases.voidPurchase(purchaseId);

    final result = await suppliers.balanceOf(supplierId);
    expect(result.of(Currency.syp), -100000);
    expect(result.hasAdvance, isTrue);
    expect(result.owed, isFalse);
    await expectLater(
      suppliers.setActive(supplierId, false),
      _appError(AppError.supplierHasDebt),
    );
  });

  test('listForSupplier is newest first and only this supplier', () async {
    final other = await suppliers.create(const SupplierInput(name: 'آخر'));
    await creditPurchase(total: 100000);
    final first = await pay(1000);
    final second = await pay(2000);
    expect(await payments.listForSupplier(other), isEmpty);
    expect((await payments.listForSupplier(supplierId)).map((e) => e.id), [second, first]);
  });
}
