import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dukan_special_app/core/backup/backup_models.dart';
import 'package:dukan_special_app/core/backup/backup_service.dart';
import 'package:dukan_special_app/core/currency/currency.dart';
import 'package:dukan_special_app/core/database/app_database.dart';
import 'package:dukan_special_app/core/database/migrations.dart';
import 'package:dukan_special_app/core/database/schema.dart';
import 'package:dukan_special_app/core/errors/app_exceptions.dart';
import 'package:dukan_special_app/data/models/product.dart';
import 'package:dukan_special_app/data/repositories/product_repository.dart';
import 'package:dukan_special_app/data/repositories/settings_repository.dart';

Matcher _backupError(BackupError error) =>
    throwsA(isA<BackupException>().having((e) => e.error, 'error', error));

void main() {
  late Directory tmp;
  late AppDatabase appDb;
  late BackupService service;
  late ProductRepository products;
  late SettingsRepository settings;
  late DateTime now;

  // تم نقل الدالة للأعلى وإزالة الشرطة السفلية
  BackupService newService({Future<void> Function()? afterReplace}) {
    return BackupService(
      appDb: appDb,
      baseDir: Directory(p.join(tmp.path, 'app')),
      factory: databaseFactoryFfi,
      clock: () {
        now = now.add(const Duration(seconds: 1));
        return now;
      },
      afterReplace: afterReplace,
    );
  }

  setUpAll(sqfliteFfiInit);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dukan_backup_test_');
    Directory(p.join(tmp.path, 'db')).createSync();
    now = DateTime(2026, 10, 18, 12);
    appDb = AppDatabase.forTesting(
      path: p.join(tmp.path, 'db', 'dukan.db'),
      factory: databaseFactoryFfi,
    );
    service = newService(); // استخدام الاسم الجديد بدون شرطة سفليّة
    products = ProductRepository(appDb);
    settings = SettingsRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
    tmp.deleteSync(recursive: true);
  });

  Future<void> seed() async {
    await settings.completeSetup(
      baseCurrency: Currency.syp,
      exchangeRate: 15000,
      sypRoundingStep: 100,
    );
    await products.create(const ProductInput(name: 'A', salePrice: 100));
    await products.create(const ProductInput(name: 'B', salePrice: 200));
  }

  Future<File> exportToFile(String name) async {
    final file = File(p.join(tmp.path, name));
    await file.writeAsBytes(await service.createBackupBytes());
    return file;
  }

  Future<List<String>> productNames() async =>
      (await products.list()).map((product) => product.name).toList();

  group('creating a backup', () {
    test('the exported bytes are a valid backup with the same data', () async {
      await seed();
      final file = await exportToFile('copy.db');

      final info = await service.inspect(file.path);
      expect(info.products, 2);
      expect(info.userVersion, currentDbVersion);
      expect(info.invoices, 0);
      expect(info.lastInvoiceAt, isNull);
      expect(info.sizeBytes, greaterThan(0));

      // The live database keeps working after the export.
      expect(await productNames(), ['A', 'B']);
    });

    test('currentInfo describes the live database', () async {
      await seed();
      final info = await service.currentInfo();
      expect(info.products, 2);
      expect(info.customers, 0);
      expect(info.suppliers, 0);
      expect(info.userVersion, currentDbVersion);
      expect(info.sizeBytes, greaterThan(0));
    });

    test('the export file name follows the clock', () {
      expect(service.exportFileName(), startsWith('dukan_backup_2026-10-18_'));
      expect(service.exportFileName(), endsWith('.db'));
    });
  });

  group('inspect', () {
    test('rejects a file that is not an SQLite database', () async {
      final text = File(p.join(tmp.path, 'text.db'))
        ..writeAsStringSync('hello, this is not a database at all');
      await expectLater(
        service.inspect(text.path),
        _backupError(BackupError.notSqlite),
      );

      final empty = File(p.join(tmp.path, 'empty.db'))
        ..writeAsBytesSync(const []);
      await expectLater(
        service.inspect(empty.path),
        _backupError(BackupError.notSqlite),
      );
    });

    test('a missing file cannot be read', () async {
      await expectLater(
        service.inspect(p.join(tmp.path, 'nope.db')),
        _backupError(BackupError.readFailed),
      );
    });

    test('rejects a database that is not from this app', () async {
      final path = p.join(tmp.path, 'other.db');
      final other = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => db.execute('CREATE TABLE things (x INTEGER)'),
        ),
      );
      await other.close();
      await expectLater(
        service.inspect(path),
        _backupError(BackupError.notOurDatabase),
      );
    });

    test('rejects a backup made by a newer version of the app', () async {
      await seed();
      final file = await exportToFile('newer.db');
      final db = await databaseFactoryFfi.openDatabase(
        file.path,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db.execute('PRAGMA user_version = ${currentDbVersion + 1}');
      await db.close();
      await expectLater(
        service.inspect(file.path),
        _backupError(BackupError.newerVersion),
      );
    });

    test('rejects a damaged file', () async {
      await seed();
      final file = await exportToFile('damaged.db');
      final bytes = await file.readAsBytes();
      // Keep the 100-byte SQLite header, overwrite the rest with garbage.
      for (var i = 100; i < bytes.length; i++) {
        bytes[i] = 0xFF;
      }
      await file.writeAsBytes(bytes);
      await expectLater(
        service.inspect(file.path),
        throwsA(isA<BackupException>()),
      );
    });
  });

  group('restoring', () {
    test(
      'brings the old data back and keeps a safety copy of the current data',
      () async {
        await seed();
        final backup = await exportToFile('backup.db');

        await products.create(const ProductInput(name: 'C', salePrice: 300));
        await settings.updateExchangeRate(16000);
        expect(await productNames(), ['A', 'B', 'C']);

        await service.restoreFrom(backup.path);

        expect(await productNames(), ['A', 'B']);
        expect((await settings.load()).exchangeRate, 15000);

        final safety = await service.listBackups(kind: BackupKind.safety);
        expect(safety, hasLength(1));
        final safetyInfo = await service.inspect(safety.single.file.path);
        expect(safetyInfo.products, 3); // the data that was replaced
      },
    );

    test(
      'an older (version 1) backup is migrated to the current schema',
      () async {
        final path = p.join(tmp.path, 'v1.db');
        final v1 = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              for (final sql in schemaV1) {
                await db.execute(sql);
              }
              await db.insert(Tables.products, {
                'name': 'قديم',
                'name_normalized': 'قديم',
                'created_at': '2026-01-01T00:00:00.000Z',
                'updated_at': '2026-01-01T00:00:00.000Z',
              });
            },
          ),
        );
        await v1.close();

        final info = await service.inspect(path);
        expect(info.userVersion, 1);
        expect(info.suppliers, 0);

        await service.restoreFrom(path);

        final db = await appDb.database;
        final version = await db.rawQuery('PRAGMA user_version');
        expect(version.first.values.first, currentDbVersion);
        final tables = {
          for (final row in await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table'",
          ))
            row['name'] as String,
        };
        expect(tables, containsAll([Tables.suppliers, Tables.purchases]));
        expect(await productNames(), ['قديم']);
      },
    );

    test(
      'a failure after the replacement rolls back to the previous data',
      () async {
        await seed();
        final backup = await exportToFile('backup.db');
        await products.create(const ProductInput(name: 'C', salePrice: 300));

        final failing = newService(
          afterReplace: () async => throw StateError('boom'),
        );
        await expectLater(
          failing.restoreFrom(backup.path),
          _backupError(BackupError.restoreFailed),
        );

        // Nothing was lost: C is still there and the database works.
        expect(await productNames(), ['A', 'B', 'C']);
        await products.create(const ProductInput(name: 'D', salePrice: 1));
        expect(await productNames(), ['A', 'B', 'C', 'D']);
      },
    );

    test('an invalid file is rejected before anything is touched', () async {
      await seed();
      final bad = File(p.join(tmp.path, 'bad.db'))
        ..writeAsStringSync('not a database, just text here');

      await expectLater(
        service.restoreFrom(bad.path),
        _backupError(BackupError.notSqlite),
      );

      expect(await productNames(), ['A', 'B']);
      expect(await service.listBackups(kind: BackupKind.safety), isEmpty);
    });
  });

  group('internal backups', () {
    test(
      'automatic backups are created and only the newest 7 are kept',
      () async {
        await seed();
        for (var i = 0; i < 9; i++) {
          await service.createAutoBackup();
        }
        final autos = await service.listBackups(kind: BackupKind.auto);
        expect(autos, hasLength(BackupService.autoKeep));
        expect(autos.every((b) => b.name.startsWith('auto_')), isTrue);
        expect(autos.first.sizeBytes, greaterThan(0));
        // Each kept file is a valid backup.
        expect((await service.inspect(autos.first.file.path)).products, 2);
      },
    );

    test('only the newest 3 safety copies are kept', () async {
      await seed();
      final backup = await exportToFile('backup.db');
      for (var i = 0; i < 5; i++) {
        await service.restoreFrom(backup.path);
      }
      expect(
        await service.listBackups(kind: BackupKind.safety),
        hasLength(BackupService.safetyKeep),
      );
    });

    test('a backup can be deleted', () async {
      await seed();
      final file = await service.createAutoBackup();
      expect(await file.exists(), isTrue);
      await service.deleteBackup(file);
      expect(await file.exists(), isFalse);
      expect(await service.listBackups(), isEmpty);
    });
  });

  test('stageIncoming writes the picked bytes to a temporary file', () async {
    final staged = await service.stageIncoming(
      Stream<List<int>>.fromIterable([
        [1, 2, 3],
        [4, 5],
      ]),
    );
    expect(await staged.readAsBytes(), [1, 2, 3, 4, 5]);
    await service.clearStaging();
    expect(await staged.exists(), isFalse);
    expect(await service.tmpDir.exists(), isFalse);
  });
}
