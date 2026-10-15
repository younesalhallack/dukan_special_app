import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/core/database/app_database.dart';
import 'package:dukan_special_app/core/errors/app_exceptions.dart';
import 'package:dukan_special_app/data/models/product.dart';
import 'package:dukan_special_app/data/models/stock_movement.dart';
import 'package:dukan_special_app/data/repositories/category_repository.dart';
import 'package:dukan_special_app/data/repositories/product_repository.dart';

Matcher _appError(AppError error) => throwsA(
      isA<AppException>().having((e) => e.error, 'error', error),
    );

void main() {
  late Directory tmp;
  late AppDatabase appDb;
  late ProductRepository repo;
  late CategoryRepository categories;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dukan_product_test_');
    appDb = AppDatabase.forTesting(
      path: p.join(tmp.path, 'test.db'),
      factory: databaseFactoryFfi,
    );
    repo = ProductRepository(appDb);
    categories = CategoryRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
    tmp.deleteSync(recursive: true);
  });

  Future<int> add(
    String name, {
    int price = 100,
    String? barcode,
    int? categoryId,
    double quantity = 0,
    double? threshold,
  }) {
    return repo.create(ProductInput(
      name: name,
      salePrice: price,
      barcode: barcode,
      categoryId: categoryId,
      initialQuantity: quantity,
      lowStockThreshold: threshold,
    ));
  }

  group('create / read', () {
    test('stores the product and its prices with currencies', () async {
      final id = await repo.create(const ProductInput(
        name: '  شاي أخضر ',
        costPrice: 150,
        costCurrency: Currency.usd,
        salePrice: 25000,
        saleCurrency: Currency.syp,
      ));
      final product = (await repo.getById(id))!;
      expect(product.name, 'شاي أخضر');
      expect(product.costPrice, 150);
      expect(product.costCurrency, Currency.usd);
      expect(product.salePrice, 25000);
      expect(product.saleCurrency, Currency.syp);
      expect(product.quantity, 0);
      expect(product.isActive, isTrue);
    });

    test('an opening quantity is recorded as a stock movement', () async {
      final id = await add('سكر', quantity: 12);
      final moves = await repo.movementsFor(id);
      expect(moves, hasLength(1));
      expect(moves.first.changeQty, 12);
      expect(moves.first.reason, StockReasons.adjustment);
      expect(moves.first.note, StockNotes.openingStock);
    });

    test('no movement is recorded when the opening quantity is zero', () async {
      final id = await add('ملح');
      expect(await repo.movementsFor(id), isEmpty);
    });

    test('validation errors', () async {
      await expectLater(add('  '), _appError(AppError.invalidName));
      await expectLater(add('x', price: -1), _appError(AppError.invalidPrice));
      await expectLater(
        add('x', quantity: -1),
        _appError(AppError.invalidQuantity),
      );
      await expectLater(
        add('x', threshold: -2),
        _appError(AppError.invalidQuantity),
      );
    });
  });

  group('barcode', () {
    test('must be unique, but many products may have none', () async {
      await add('أ', barcode: '6221');
      await expectLater(
        add('ب', barcode: '6221'),
        _appError(AppError.duplicateBarcode),
      );
      await add('ج');
      await add('د', barcode: '   ');
    });

    test('Arabic-Indic digits are stored as Western digits', () async {
      final id = await add('هـ', barcode: '١٢٣٤');
      expect((await repo.getById(id))!.barcode, '1234');
    });

    test('findByBarcode returns only active products', () async {
      final id = await add('أ', barcode: '777');
      expect((await repo.findByBarcode('777'))!.id, id);
      expect(await repo.findByBarcode('000'), isNull);
      await repo.setActive(id, false);
      expect(await repo.findByBarcode('777'), isNull);
    });

    test('findByBarcodeAnyStatus also finds hidden products', () async {
      final id = await add('أ', barcode: '555');
      await repo.setActive(id, false);
      expect(await repo.findByBarcode('555'), isNull);
      expect((await repo.findByBarcodeAnyStatus('555'))!.id, id);
      expect(await repo.findByBarcodeAnyStatus('999'), isNull);
      expect(await repo.findByBarcodeAnyStatus('  '), isNull);
    });
  });

  group('search', () {
    test('ignores Arabic spelling variations', () async {
      await add('شاي أخضر');
      await add('أرز مصري');
      expect((await repo.list(query: 'اخضر')).map((p) => p.name), ['شاي أخضر']);
      expect((await repo.list(query: 'ارز')).map((p) => p.name), ['أرز مصري']);
      expect(await repo.list(query: 'شاى'), hasLength(1));
    });

    test('every word must match', () async {
      await add('شاي أخضر');
      await add('شاي أسود');
      expect(await repo.list(query: 'شاي'), hasLength(2));
      expect(await repo.list(query: 'شاي اخضر'), hasLength(1));
      expect(await repo.list(query: 'شاي ابيض'), isEmpty);
    });

    test('matches part of a barcode', () async {
      await add('أ', barcode: '6221234567');
      await add('ب', barcode: '9990000000');
      expect((await repo.list(query: '1234')).map((p) => p.name), ['أ']);
    });

    test('LIKE wildcards in the query are treated literally', () async {
      await add('عصير');
      await add('100% طبيعي');
      final found = await repo.list(query: '%');
      expect(found.map((p) => p.name), ['100% طبيعي']);
    });

    test('filters by category and hides inactive products', () async {
      final drinks = await categories.create('مشروبات');
      final a = await add('عصير', categoryId: drinks);
      await add('أرز');
      expect(await repo.list(), hasLength(2));
      expect((await repo.list(categoryId: drinks)).map((p) => p.id), [a]);
      expect((await repo.list(categoryId: drinks)).first.categoryName, 'مشروبات');

      await repo.setActive(a, false);
      expect(await repo.list(), hasLength(1));
      expect(await repo.list(includeInactive: true), hasLength(2));
    });
  });

  group('update', () {
    test('changes the editable fields but never the quantity', () async {
      final id = await add('شاي', price: 100, quantity: 7);
      await repo.update(
        id,
        const ProductInput(
          name: 'شاي ممتاز',
          salePrice: 150,
          initialQuantity: 999, // ignored by update
        ),
      );
      final product = (await repo.getById(id))!;
      expect(product.name, 'شاي ممتاز');
      expect(product.salePrice, 150);
      expect(product.quantity, 7);
      expect(await repo.list(query: 'ممتاز'), hasLength(1));
    });

    test('keeping its own barcode is fine, taking another one is not', () async {
      final a = await add('أ', barcode: '111');
      await add('ب', barcode: '222');
      await repo.update(a, const ProductInput(name: 'أ', salePrice: 1, barcode: '111'));
      await expectLater(
        repo.update(a, const ProductInput(name: 'أ', salePrice: 1, barcode: '222')),
        _appError(AppError.duplicateBarcode),
      );
    });

    test('a missing product reports notFound', () async {
      await expectLater(
        repo.update(999, const ProductInput(name: 'x', salePrice: 1)),
        _appError(AppError.notFound),
      );
      await expectLater(repo.setActive(999, false), _appError(AppError.notFound));
    });
  });

  group('adjustStock', () {
    test('adds and reduces stock and logs each movement', () async {
      final id = await add('سكر', quantity: 10);
      expect(
        await repo.adjustStock(
          productId: id,
          delta: 5,
          reason: StockReasons.restock,
          note: ' فاتورة مورد ',
        ),
        15,
      );
      expect(
        await repo.adjustStock(
          productId: id,
          delta: -2.5,
          reason: StockReasons.adjustment,
        ),
        12.5,
      );
      expect((await repo.getById(id))!.quantity, 12.5);

      final moves = await repo.movementsFor(id);
      expect(moves, hasLength(3)); // opening + 2
      expect(moves.first.changeQty, -2.5);
      expect(moves[1].note, 'فاتورة مورد');
    });

    test('never makes the stock negative and changes nothing on failure', () async {
      final id = await add('سكر', quantity: 3);
      await expectLater(
        repo.adjustStock(productId: id, delta: -4, reason: StockReasons.adjustment),
        _appError(AppError.negativeStock),
      );
      expect((await repo.getById(id))!.quantity, 3);
      expect(await repo.movementsFor(id), hasLength(1)); // only the opening one
    });

    test('rejects a zero change, unknown product and unsupported reason', () async {
      final id = await add('سكر', quantity: 3);
      await expectLater(
        repo.adjustStock(productId: id, delta: 0, reason: StockReasons.restock),
        _appError(AppError.invalidQuantity),
      );
      await expectLater(
        repo.adjustStock(productId: 999, delta: 1, reason: StockReasons.restock),
        _appError(AppError.notFound),
      );
      await expectLater(
        repo.adjustStock(productId: id, delta: 1, reason: StockReasons.sale),
        throwsArgumentError,
      );
    });

    test('fractional quantities do not accumulate float noise', () async {
      final id = await add('جبنة', quantity: 0.1);
      final next = await repo.adjustStock(
        productId: id,
        delta: 0.2,
        reason: StockReasons.restock,
      );
      expect(next, 0.3);
    });
  });

  group('lowStock', () {
    test('uses the product threshold, falling back to the default', () async {
      await add('أ', quantity: 3); // default 5 -> low
      await add('ب', quantity: 3, threshold: 2); // own 2 -> not low
      await add('ج', quantity: 10, threshold: 20); // own 20 -> low
      await add('د', quantity: 50); // fine
      final hidden = await add('هـ', quantity: 0);
      await repo.setActive(hidden, false); // inactive -> ignored

      final low = await repo.lowStock(5);
      expect(low.map((p) => p.name), ['أ', 'ج']);
      expect(low.first.isLowStock(5), isTrue);
    });

    test('lowest quantity comes first', () async {
      await add('كثير', quantity: 4);
      await add('قليل', quantity: 1);
      final low = await repo.lowStock(5);
      expect(low.map((p) => p.name), ['قليل', 'كثير']);
    });
  });
}
