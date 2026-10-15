import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Adjust the package name if your pubspec uses a different one.
import 'package:dukan_special_app/core/database/app_database.dart';
import 'package:dukan_special_app/core/database/migrations.dart';
import 'package:dukan_special_app/core/database/schema.dart';

const _now = '2026-10-13T00:00:00.000Z';

Future<int> _insertProduct(
  Database d, {
  String name = 'p',
  String? barcode,
  String costCurrency = 'USD',
}) => d.insert(Tables.products, {
  'name': name,
  'name_normalized': name,
  'barcode': barcode,
  'cost_currency': costCurrency,
  'created_at': _now,
  'updated_at': _now,
});

Future<int> _insertTx(
  Database d, {
  String invoice = 'INV-000001',
  String paymentType = 'cash',
  int? customerId,
}) => d.insert(Tables.transactions, {
  'invoice_number': invoice,
  'customer_id': customerId,
  'currency': 'SYP',
  'exchange_rate': 15000.0,
  'total_amount': 1000,
  'payment_type': paymentType,
  'created_at': _now,
});

void main() {
  late Directory tmp;
  late AppDatabase db;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dukan_test_');
    db = AppDatabase.forTesting(
      path: p.join(tmp.path, 'test.db'),
      factory: databaseFactoryFfi,
    );
  });

  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('creates every required table and sets user_version', () async {
    final d = await db.database;
    final rows = await d.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    final names = rows.map((r) => r['name'] as String).toSet();
    expect(names, containsAll(requiredTables));

    final version = await d.rawQuery('PRAGMA user_version');
    expect(version.first.values.first, currentDbVersion);
  });

  test('seeds default settings and leaves currency/rate unset', () async {
    final d = await db.database;
    final rows = await d.query(Tables.settings);
    final map = {
      for (final r in rows) r['key'] as String: r['value'] as String,
    };
    expect(map, defaultSettings);
    expect(map.containsKey(SettingKeys.baseCurrency), isFalse);
    expect(map.containsKey(SettingKeys.exchangeRate), isFalse);
  });

  test('foreign keys are enforced', () async {
    final d = await db.database;
    final pragma = await d.rawQuery('PRAGMA foreign_keys');
    expect(pragma.first.values.first, 1);

    await expectLater(
      d.insert(Tables.transactionItems, {
        'transaction_id': 999,
        'product_name': 'x',
        'quantity': 1,
        'unit_price': 1,
        'unit_cost': 1,
        'line_total': 1,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('rejects an unknown currency', () async {
    final d = await db.database;
    await expectLater(
      _insertProduct(d, costCurrency: 'EUR'),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('credit invoice requires a customer', () async {
    final d = await db.database;
    await expectLater(
      _insertTx(d, paymentType: 'credit'),
      throwsA(isA<DatabaseException>()),
    );
    // A cash invoice without a customer is fine.
    expect(await _insertTx(d, invoice: 'INV-000002'), isPositive);
  });

  test('barcode is unique, but many products may have no barcode', () async {
    final d = await db.database;
    await _insertProduct(d, name: 'a', barcode: '123');
    await expectLater(
      _insertProduct(d, name: 'b', barcode: '123'),
      throwsA(isA<DatabaseException>()),
    );
    await _insertProduct(d, name: 'c');
    await _insertProduct(d, name: 'd');
  });

  test('deleting an invoice cascades to its items', () async {
    final d = await db.database;
    final productId = await _insertProduct(d);
    final txId = await _insertTx(d);
    await d.insert(Tables.transactionItems, {
      'transaction_id': txId,
      'product_id': productId,
      'product_name': 'p',
      'quantity': 2,
      'unit_price': 500,
      'unit_cost': 300,
      'line_total': 1000,
    });
    await d.delete(Tables.transactions, where: 'id = ?', whereArgs: [txId]);
    expect(await d.query(Tables.transactionItems), isEmpty);
  });

  test('runInTransaction rolls back when the action throws', () async {
    await expectLater(
      db.runInTransaction((txn) async {
        await txn.insert(Tables.categories, {
          'name': 'Drinks',
          'name_normalized': 'drinks',
          'created_at': _now,
        });
        throw StateError('boom');
      }),
      throwsStateError,
    );
    final d = await db.database;
    expect(await d.query(Tables.categories), isEmpty);
  });

  test('data survives close and reopen', () async {
    final d = await db.database;
    await d.insert(Tables.categories, {
      'name': 'Drinks',
      'name_normalized': 'drinks',
      'created_at': _now,
    });
    final reopened = await db.reopen();
    expect(await reopened.query(Tables.categories), hasLength(1));
  });
}
