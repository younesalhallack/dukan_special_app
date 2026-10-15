import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dukan_special_app/core/database/app_database.dart';
import 'package:dukan_special_app/core/errors/app_exceptions.dart';
import 'package:dukan_special_app/data/models/product.dart';
import 'package:dukan_special_app/data/repositories/category_repository.dart';
import 'package:dukan_special_app/data/repositories/product_repository.dart';

Matcher _appError(AppError error) => throwsA(
      isA<AppException>().having((e) => e.error, 'error', error),
    );

void main() {
  late Directory tmp;
  late AppDatabase appDb;
  late CategoryRepository categories;
  late ProductRepository products;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dukan_category_test_');
    appDb = AppDatabase.forTesting(
      path: p.join(tmp.path, 'test.db'),
      factory: databaseFactoryFfi,
    );
    categories = CategoryRepository(appDb);
    products = ProductRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
    tmp.deleteSync(recursive: true);
  });

  test('create and list, sorted by name', () async {
    await categories.create('مشروبات');
    await categories.create('ألبان');
    final names = (await categories.list()).map((c) => c.name).toList();
    expect(names, ['ألبان', 'مشروبات']);
  });

  test('blank name is rejected', () async {
    await expectLater(categories.create('   '), _appError(AppError.invalidName));
  });

  test('duplicates are detected after normalization', () async {
    await categories.create('ألبان');
    await expectLater(
      categories.create('  البان '),
      _appError(AppError.duplicateCategory),
    );
  });

  test('rename succeeds and rejects a clashing name', () async {
    final dairy = await categories.create('ألبان');
    final drinks = await categories.create('مشروبات');

    await categories.rename(drinks, 'عصائر');
    expect((await categories.list()).map((c) => c.name), contains('عصائر'));

    await expectLater(
      categories.rename(drinks, 'البان'),
      _appError(AppError.duplicateCategory),
    );
    // Renaming to its own name (different spelling) is allowed.
    await categories.rename(dairy, 'البان');
  });

  test('rename of a missing category reports notFound', () async {
    await expectLater(categories.rename(999, 'x'), _appError(AppError.notFound));
  });

  test('delete hides the category and uncategorizes its products', () async {
    final categoryId = await categories.create('مشروبات');
    final productId = await products.create(
      ProductInput(name: 'عصير', categoryId: categoryId, salePrice: 100),
    );

    await categories.delete(categoryId);

    expect(await categories.list(), isEmpty);
    final product = await products.getById(productId);
    expect(product!.categoryId, isNull);

    // Creating the same name again brings the hidden category back.
    expect(await categories.create('مشروبات'), categoryId);
    expect(await categories.list(), hasLength(1));
  });
}
