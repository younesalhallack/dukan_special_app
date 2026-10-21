import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';
import 'schema.dart';

/// Owns the single SQLite connection of the app.
///
/// Repositories obtain the database through [database] and never open their
/// own connection. [BackupService] (a later step) uses [close], [reopen] and
/// [databasePath] to export and restore the file safely.
class AppDatabase {
  AppDatabase._({String? path, DatabaseFactory? factory})
      : _overridePath = path,
        _factoryOverride = factory;

  /// The app-wide instance.
  static final AppDatabase instance = AppDatabase._();

  /// Creates an isolated instance pointing at [path], for unit tests.
  @visibleForTesting
  factory AppDatabase.forTesting({
    required String path,
    required DatabaseFactory factory,
  }) =>
      AppDatabase._(path: path, factory: factory);

  static const String fileName = 'dukan.db';

  final String? _overridePath;
  final DatabaseFactory? _factoryOverride;

  Database? _db;
  Future<Database>? _opening;

  /// Held while an exclusive operation (backup / restore) owns the file.
  Completer<void>? _lock;

  DatabaseFactory get _factory => _factoryOverride ?? databaseFactory;

  /// Absolute path of the database file.
  Future<String> databasePath() async =>
      _overridePath ?? p.join(await _factory.getDatabasesPath(), fileName);

  /// The open database. Opens it on first use; concurrent callers share the
  /// same opening operation.
  Future<Database> get database async {
    // Wait while a backup / restore owns the database file.
    while (_lock != null) {
      await _lock!.future;
    }
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  Future<Database> _open() async {
    final db = await _factory.openDatabase(
      await databasePath(),
      options: OpenDatabaseOptions(
        version: currentDbVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onDowngrade: _onDowngrade,
      ),
    );
    _db = db;
    return db;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    for (final sql in schemaV1) {
      await db.execute(sql);
    }
    final batch = db.batch();
    defaultSettings.forEach((key, value) {
      batch.insert(Tables.settings, {'key': key, 'value': value});
    });
    await batch.commit(noResult: true);
    // Fresh installs end up in the same schema as upgraded ones.
    await _runMigrations(db, 1, version);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) =>
      _runMigrations(db, oldVersion, newVersion);

  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    // The file was created by a newer version of the app. Never destroy data.
    throw StateError(
      'Database version $oldVersion is newer than the app supports '
      '($newVersion). Update the app.',
    );
  }

  /// Runs migrations (from + 1) .. to. sqflite calls onCreate/onUpgrade inside
  /// a transaction, so a failing step rolls the whole upgrade back.
  Future<void> _runMigrations(Database db, int from, int to) async {
    for (var version = from + 1; version <= to; version++) {
      final steps = migrations[version];
      if (steps == null) {
        throw StateError('Missing migration for database version $version');
      }
      for (final sql in steps) {
        await db.execute(sql);
      }
    }
  }

  /// Runs [action] atomically: if it throws, every change is rolled back.
  Future<T> runInTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  /// Closes the connection. Safe to call when already closed.
  Future<void> close() async {
    final pending = _opening;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // Opening failed; nothing to close.
      }
    }
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) await db.close();
  }

  /// Closes and reopens the database (used after a restore replaced the file).
  Future<Database> reopen() async {
    await close();
    return database;
  }

  /// Closes the connection and runs [action] with exclusive access to the
  /// database file (its path is passed in). Everyone who asks for [database]
  /// meanwhile waits. The connection is NOT reopened here: the next call of
  /// [database] reopens it, on whatever file is there then (and runs the
  /// migrations if it is an older one).
  Future<T> runExclusive<T>(Future<T> Function(String path) action) async {
    while (_lock != null) {
      await _lock!.future;
    }
    final lock = Completer<void>();
    _lock = lock;
    try {
      await close();
      return await action(await databasePath());
    } finally {
      _lock = null;
      lock.complete();
    }
  }
}
