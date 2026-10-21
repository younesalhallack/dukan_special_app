import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dukan_special_app/core/database/app_database.dart';
import 'package:dukan_special_app/core/database/schema.dart';

void main() {
  late Directory tmp;

  setUpAll(sqfliteFfiInit);
  setUp(() => tmp = Directory.systemTemp.createTempSync('dukan_lock_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  AppDatabase open(String name) => AppDatabase.forTesting(
        path: p.join(tmp.path, name),
        factory: databaseFactoryFfi,
      );

  test('database() waits while an exclusive action runs, then sees the replaced file', () async {
    final a = open('a.db');
    final b = open('b.db');
    await a.database;
    final dbB = await b.database;
    await dbB.insert(Tables.settings, {'key': 'marker', 'value': 'from-b'});
    await b.close();

    final release = Completer<void>();
    final exclusive = a.runExclusive((path) async {
      await release.future;
      final target = File(path);
      if (await target.exists()) await target.delete();
      await File(p.join(tmp.path, 'b.db')).copy(path);
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));

    var opened = false;
    final pending = a.database.then((db) {
      opened = true;
      return db;
    });
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(opened, isFalse, reason: 'database() must wait for the exclusive action');

    release.complete();
    await exclusive;
    final db = await pending;
    expect(opened, isTrue);

    final rows = await db.query(Tables.settings, where: 'key = ?', whereArgs: ['marker']);
    expect(rows.single['value'], 'from-b');
    await a.close();
  });

  test('the action gets the database path and the connection is closed meanwhile', () async {
    final a = open('a.db');
    final db = await a.database;
    String? seenPath;
    await a.runExclusive((path) async {
      seenPath = path;
      expect(db.isOpen, isFalse);
    });
    expect(seenPath, p.join(tmp.path, 'a.db'));
    // The next call reopens it.
    expect((await a.database).isOpen, isTrue);
    await a.close();
  });

  test('exclusive actions run one after the other', () async {
    final a = open('a.db');
    final order = <String>[];
    final first = a.runExclusive((_) async {
      order.add('first start');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      order.add('first end');
    });
    final second = a.runExclusive((_) async {
      order.add('second start');
    });
    await Future.wait([first, second]);
    expect(order, ['first start', 'first end', 'second start']);
    await a.close();
  });

  test('the lock is released when the action throws', () async {
    final a = open('a.db');
    await expectLater(
      a.runExclusive<void>((_) async => throw StateError('boom')),
      throwsStateError,
    );
    expect((await a.database).isOpen, isTrue);
    await a.close();
  });
}
