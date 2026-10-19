import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dukan_special_app/core/database/app_database.dart';
import 'package:dukan_special_app/core/database/migrations.dart';
import 'package:dukan_special_app/core/database/schema.dart';

void main() {
  late Directory tmp;

  setUpAll(sqfliteFfiInit);

  setUp(() => tmp = Directory.systemTemp.createTempSync('dukan_migration_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('a version 1 database is upgraded to the current version', () async {
    final path = p.join(tmp.path, 'v1.db');

    // Build a database exactly as version 1 of the app created it.
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final sql in schemaV1) {
            await db.execute(sql);
          }
          await db.insert(Tables.settings, {'key': SettingKeys.language, 'value': 'en'});
          await db.insert(Tables.transactions, {
            'invoice_number': 'OLD-1',
            'currency': 'SYP',
            'exchange_rate': 15000.0,
            'total_amount': 500,
            'payment_type': 'cash',
            'created_at': '2026-01-01T00:00:00.000Z',
          });
        },
      ),
    );
    await v1.close();

    // Open it with the current app code: onUpgrade runs the migrations.
    final appDb = AppDatabase.forTesting(path: path, factory: databaseFactoryFfi);
    final db = await appDb.database;

    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.first.values.first, currentDbVersion);

    // Old data is intact and the new column has its default.
    final invoice = (await db.query(Tables.transactions)).single;
    expect(invoice['invoice_number'], 'OLD-1');
    expect(invoice['total_amount'], 500);
    expect(invoice['discount_amount'], 0);

    final settings = {
      for (final row in await db.query(Tables.settings))
        row['key'] as String: row['value'] as String,
    };
    expect(settings[SettingKeys.language], 'en'); // not overwritten
    expect(settings[SettingKeys.allowNegativeStock], '1');
    expect(settings[SettingKeys.invoiceCounter], '0');

    await appDb.close();
  });

  test('a version 2 database is upgraded: payments get is_voided = 0', () async {
    final path = p.join(tmp.path, 'v2.db');

    // Build a database exactly as version 2 of the app created it.
    final v2 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          for (final sql in schemaV1) {
            await db.execute(sql);
          }
          for (final sql in migrations[2]!) {
            await db.execute(sql);
          }
          final customerId = await db.insert(Tables.customers, {
            'name': 'أحمد',
            'name_normalized': 'احمد',
            'created_at': '2026-10-01T00:00:00.000Z',
          });
          await db.insert(Tables.customerPayments, {
            'customer_id': customerId,
            'amount': 1000,
            'currency': 'SYP',
            'exchange_rate': 15000.0,
            'applied_amount': 1000,
            'applied_currency': 'SYP',
            'created_at': '2026-10-02T00:00:00.000Z',
          });
        },
      ),
    );
    await v2.close();

    final appDb = AppDatabase.forTesting(path: path, factory: databaseFactoryFfi);
    final db = await appDb.database;

    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.first.values.first, currentDbVersion);
    expect(currentDbVersion, greaterThanOrEqualTo(3));

    final payment = (await db.query(Tables.customerPayments)).single;
    expect(payment['amount'], 1000);
    expect(payment['is_voided'], 0);

    await appDb.close();
  });

  test('upgrading does not reset values the user already changed', () async {
    final path = p.join(tmp.path, 'v1b.db');
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final sql in schemaV1) {
            await db.execute(sql);
          }
          // A setting that migration 2 also writes, already present.
          await db.insert(Tables.settings, {'key': SettingKeys.invoiceCounter, 'value': '41'});
        },
      ),
    );
    await v1.close();

    final appDb = AppDatabase.forTesting(path: path, factory: databaseFactoryFfi);
    final db = await appDb.database;
    final rows = await db.query(
      Tables.settings,
      where: 'key = ?',
      whereArgs: [SettingKeys.invoiceCounter],
    );
    expect(rows.single['value'], '41');
    await appDb.close();
  });

  test('a version 2 database is upgraded to version 3 (payments can be voided)', () async {
    final path = p.join(tmp.path, 'v2.db');

    // Build a database exactly as version 2 of the app left it.
    final v2 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          for (final sql in schemaV1) {
            await db.execute(sql);
          }
          for (final sql in migrations[2]!) {
            await db.execute(sql);
          }
          await db.insert(Tables.customers, {
            'name': 'زبون',
            'name_normalized': 'زبون',
            'created_at': '2026-10-01T00:00:00.000Z',
          });
          await db.insert(Tables.customerPayments, {
            'customer_id': 1,
            'amount': 500,
            'currency': 'SYP',
            'exchange_rate': 15000.0,
            'applied_amount': 500,
            'applied_currency': 'SYP',
            'created_at': '2026-10-02T00:00:00.000Z',
          });
        },
      ),
    );
    await v2.close();

    final appDb = AppDatabase.forTesting(path: path, factory: databaseFactoryFfi);
    final db = await appDb.database;

    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.first.values.first, currentDbVersion);
    expect(currentDbVersion, greaterThanOrEqualTo(3));

    final payment = (await db.query(Tables.customerPayments)).single;
    expect(payment['amount'], 500);
    expect(payment['is_voided'], 0);

    await appDb.close();
  });

  test('a version 3 database is upgraded to version 4 (suppliers and purchases)', () async {
    final path = p.join(tmp.path, 'v3.db');

    // Build a database exactly as version 3 of the app left it.
    final v3 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          for (final sql in schemaV1) {
            await db.execute(sql);
          }
          for (final sql in migrations[2]!) {
            await db.execute(sql);
          }
          for (final sql in migrations[3]!) {
            await db.execute(sql);
          }
          await db.insert(Tables.products, {
            'name': 'منتج',
            'name_normalized': 'منتج',
            'created_at': '2026-10-01T00:00:00.000Z',
            'updated_at': '2026-10-01T00:00:00.000Z',
          });
          await db.insert(Tables.stockMovements, {
            'product_id': 1,
            'change_qty': 5.0,
            'reason': 'restock',
            'created_at': '2026-10-01T00:00:00.000Z',
          });
        },
      ),
    );
    await v3.close();

    final appDb = AppDatabase.forTesting(path: path, factory: databaseFactoryFfi);
    final db = await appDb.database;

    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.first.values.first, currentDbVersion);
    expect(currentDbVersion, greaterThanOrEqualTo(4));

    final tables = {
      for (final row in await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
        row['name'] as String,
    };
    expect(
      tables,
      containsAll([
        Tables.suppliers,
        Tables.purchases,
        Tables.purchaseItems,
        Tables.supplierPayments,
      ]),
    );

    // The old stock movement survives and the new link column is empty.
    final movement = (await db.query(Tables.stockMovements)).single;
    expect(movement['change_qty'], 5.0);
    expect(movement['ref_purchase_id'], isNull);

    final settings = {
      for (final row in await db.query(Tables.settings))
        row['key'] as String: row['value'] as String,
    };
    expect(settings[SettingKeys.purchaseCounter], '0');

    await appDb.close();
  });
}
