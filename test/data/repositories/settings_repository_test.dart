import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/core/database/app_database.dart';
import 'package:dukan_special_app/core/database/schema.dart';
import 'package:dukan_special_app/core/utils/digits.dart';
import 'package:dukan_special_app/data/repositories/settings_repository.dart';

void main() {
  late Directory tmp;
  late AppDatabase appDb;
  late SettingsRepository repo;

  Future<List<Map<String, Object?>>> history() async {
    final db = await appDb.database;
    return db.query(Tables.exchangeRateHistory, orderBy: 'id');
  }

  setUpAll(sqfliteFfiInit);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dukan_settings_test_');
    appDb = AppDatabase.forTesting(
      path: p.join(tmp.path, 'test.db'),
      factory: databaseFactoryFfi,
    );
    repo = SettingsRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
    tmp.deleteSync(recursive: true);
  });

  test('a fresh database is not configured and has the seeded defaults',
      () async {
    final s = await repo.load();
    expect(s.isConfigured, isFalse);
    expect(s.baseCurrency, isNull);
    expect(s.exchangeRate, isNull);
    expect(s.language, 'ar');
    expect(s.sypRoundingStep, 100);
    expect(s.showDualCurrency, isTrue);
    expect(s.digitStyle, DigitStyle.western);
    expect(s.defaultLowStockThreshold, 5);
    expect(s.allowNegativeStock, isTrue);
  });

  test('completeSetup stores the values and the first rate history row',
      () async {
    await repo.completeSetup(
      baseCurrency: Currency.syp,
      exchangeRate: 15000,
      sypRoundingStep: 50,
    );
    final s = await repo.load();
    expect(s.isConfigured, isTrue);
    expect(s.baseCurrency, Currency.syp);
    expect(s.exchangeRate, 15000.0);
    expect(s.sypRoundingStep, 50);

    final rows = await history();
    expect(rows, hasLength(1));
    expect(rows.first['rate'], 15000.0);
  });

  test('updateExchangeRate appends history and ignores an unchanged rate',
      () async {
    await repo.completeSetup(
      baseCurrency: Currency.usd,
      exchangeRate: 15000,
      sypRoundingStep: 100,
    );
    await repo.updateExchangeRate(15250.5);
    expect((await repo.load()).exchangeRate, 15250.5);
    expect(await history(), hasLength(2));

    await repo.updateExchangeRate(15250.5);
    expect(await history(), hasLength(2));
  });

  test('invalid rates are rejected and nothing is written', () async {
    for (final bad in [0.0, -5.0, double.nan, double.infinity]) {
      await expectLater(repo.updateExchangeRate(bad), throwsArgumentError);
      await expectLater(
        repo.completeSetup(
          baseCurrency: Currency.syp,
          exchangeRate: bad,
          sypRoundingStep: 100,
        ),
        throwsArgumentError,
      );
    }
    expect(await history(), isEmpty);
    expect((await repo.load()).isConfigured, isFalse);
  });

  test('unsupported rounding step and language are rejected', () async {
    await expectLater(repo.setSypRoundingStep(75), throwsArgumentError);
    await expectLater(repo.setLanguage('fr'), throwsArgumentError);
    await expectLater(repo.setDefaultLowStockThreshold(-1), throwsArgumentError);
  });

  test('preferences round-trip', () async {
    await repo.setBaseCurrency(Currency.usd);
    await repo.setSypRoundingStep(500);
    await repo.setShowDualCurrency(false);
    await repo.setDigitStyle(DigitStyle.arabicIndic);
    await repo.setLanguage('en');
    await repo.setDefaultLowStockThreshold(10);
    await repo.setStoreName('  My Shop ');
    await repo.setAllowNegativeStock(false);

    final s = await repo.load();
    expect(s.baseCurrency, Currency.usd);
    expect(s.sypRoundingStep, 500);
    expect(s.showDualCurrency, isFalse);
    expect(s.digitStyle, DigitStyle.arabicIndic);
    expect(s.language, 'en');
    expect(s.defaultLowStockThreshold, 10);
    expect(s.storeName, 'My Shop');
    expect(s.allowNegativeStock, isFalse);
  });
}
