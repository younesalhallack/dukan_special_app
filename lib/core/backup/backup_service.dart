import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../database/migrations.dart';
import '../errors/app_exceptions.dart';
import 'backup_models.dart';

/// Creates, validates and restores backups of the database file.
///
/// A backup is a plain copy of the SQLite file. Everything that touches the
/// file runs through [AppDatabase.runExclusive], so no other query can open a
/// half-replaced database.
class BackupService {
  BackupService({
    required AppDatabase appDb,
    required Directory baseDir,
    DatabaseFactory? factory,
    DateTime Function()? clock,
    this.afterReplace,
  })  : _appDb = appDb,
        _base = baseDir,
        _factoryOverride = factory,
        _clock = clock ?? DateTime.now;

  final AppDatabase _appDb;
  final Directory _base;
  final DatabaseFactory? _factoryOverride;
  final DateTime Function() _clock;

  /// Test seam: runs after the database file was replaced and reopened.
  /// Throwing from it makes the restore roll back.
  final Future<void> Function()? afterReplace;

  /// Number of automatic internal backups that are kept.
  static const int autoKeep = 7;

  /// Number of safety copies (made before a restore) that are kept.
  static const int safetyKeep = 3;

  DatabaseFactory get _factory => _factoryOverride ?? databaseFactory;

  Directory get autoDir => Directory(p.join(_base.path, 'backups', 'auto'));
  Directory get safetyDir => Directory(p.join(_base.path, 'backups', 'safety'));
  Directory get tmpDir => Directory(p.join(_base.path, 'backups', 'tmp'));

  /// File name suggested when exporting a backup.
  String exportFileName() => backupFileName(_clock());

  // --- creating backups ------------------------------------------------------

  /// Flushes pending writes into the database file (harmless when the
  /// journal mode is not WAL).
  Future<void> _checkpoint() async {
    final db = await _appDb.database;
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  /// The database file as bytes, for exporting through the system dialog.
  Future<Uint8List> createBackupBytes() async {
    await _checkpoint();
    return _appDb.runExclusive((path) => File(path).readAsBytes());
  }

  Future<File> _snapshotTo(File target) async {
    await target.parent.create(recursive: true);
    if (await target.exists()) await target.delete();
    await _checkpoint();
    await _appDb.runExclusive((path) => File(path).copy(target.path));
    return target;
  }

  /// Makes an automatic internal backup and keeps only the newest
  /// [autoKeep] ones.
  Future<File> createAutoBackup() async {
    final name = backupFileName(_clock(), prefix: 'auto', withSeconds: true);
    final file = await _snapshotTo(File(p.join(autoDir.path, name)));
    await _prune(autoDir, autoKeep);
    return file;
  }

  /// Internal backups, newest first.
  Future<List<BackupFileInfo>> listBackups({BackupKind? kind}) async {
    final result = <BackupFileInfo>[];
    for (final entry in {
      BackupKind.auto: autoDir,
      BackupKind.safety: safetyDir,
    }.entries) {
      if (kind != null && kind != entry.key) continue;
      if (!await entry.value.exists()) continue;
      await for (final entity in entry.value.list()) {
        if (entity is! File || !entity.path.endsWith('.db')) continue;
        final stat = await entity.stat();
        result.add(BackupFileInfo(
          file: entity,
          sizeBytes: stat.size,
          modified: stat.modified,
          kind: entry.key,
        ));
      }
    }
    result.sort((a, b) => b.modified.compareTo(a.modified));
    return result;
  }

  Future<void> deleteBackup(File file) async {
    if (await file.exists()) await file.delete();
  }

  Future<void> _prune(Directory dir, int keep) async {
    if (!await dir.exists()) return;
    final files = <File>[
      await for (final entity in dir.list())
        if (entity is File && entity.path.endsWith('.db')) entity,
    ]..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    for (final stale in files.skip(keep)) {
      await stale.delete();
    }
  }

  // --- reading a backup ------------------------------------------------------

  /// Writes bytes picked by the user into a temporary file and returns it.
  Future<File> stageIncoming(Stream<List<int>> bytes) async {
    await tmpDir.create(recursive: true);
    final file = File(
      p.join(tmpDir.path, 'incoming_${_clock().microsecondsSinceEpoch}.db'),
    );
    final sink = file.openWrite();
    try {
      await sink.addStream(bytes);
    } finally {
      await sink.close();
    }
    return file;
  }

  Future<void> clearStaging() async {
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  }

  /// What the live database holds right now.
  Future<BackupInfo> currentInfo() async {
    final db = await _appDb.database;
    final version = await db.rawQuery('PRAGMA user_version');
    final size = await File(await _appDb.databasePath()).length();
    return BackupInfo.read(
      db,
      userVersion: (version.first.values.first as num?)?.toInt() ?? currentDbVersion,
      sizeBytes: size,
    );
  }

  /// Checks that [path] is a healthy backup of this app and describes it.
  /// Throws [BackupException] otherwise. Never modifies the file.
  Future<BackupInfo> inspect(String path) async {
    final file = File(path);
    if (!await file.exists()) throw const BackupException(BackupError.readFailed);

    final size = await file.length();
    final handle = await file.open();
    final List<int> header;
    try {
      header = await handle.read(16);
    } finally {
      await handle.close();
    }
    if (header.length < 16 || String.fromCharCodes(header) != 'SQLite format 3\u0000') {
      throw const BackupException(BackupError.notSqlite);
    }

    Database? db;
    try {
      db = await _factory.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      final integrity = await db.rawQuery('PRAGMA integrity_check');
      if (integrity.length != 1 || integrity.first.values.first != 'ok') {
        throw const BackupException(BackupError.corrupt);
      }
      final versionRows = await db.rawQuery('PRAGMA user_version');
      final version = (versionRows.first.values.first as num?)?.toInt() ?? 0;
      if (version > currentDbVersion) {
        throw const BackupException(BackupError.newerVersion);
      }
      final tableRows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tables = {for (final row in tableRows) row['name'] as String};
      if (version < 1 || !tables.containsAll(requiredTablesAt(version))) {
        throw const BackupException(BackupError.notOurDatabase);
      }
      return await BackupInfo.read(db, userVersion: version, sizeBytes: size);
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(BackupError.corrupt);
    } finally {
      await db?.close();
    }
  }

  // --- restoring -------------------------------------------------------------

  /// Replaces the live database with the backup at [sourcePath].
  ///
  /// The file is validated again, a safety copy of the current data is made,
  /// the file is replaced and the database reopened (older backups are
  /// migrated). If anything fails the safety copy is put back and a
  /// [BackupException] (`restoreFailed`) is thrown. A file that does not pass
  /// validation throws before anything is touched.
  Future<void> restoreFrom(String sourcePath) async {
    await inspect(sourcePath);

    final safety = await _snapshotTo(
      File(p.join(
        safetyDir.path,
        backupFileName(_clock(), prefix: 'safety', withSeconds: true),
      )),
    );
    await _prune(safetyDir, safetyKeep);

    try {
      await _replaceDatabaseFile(sourcePath);
      // Reopen (this migrates an older backup) and make sure it really works.
      final db = await _appDb.database;
      await db.rawQuery('PRAGMA integrity_check');
      await afterReplace?.call();
    } catch (_) {
      await _rollback(safety);
      throw const BackupException(BackupError.restoreFailed);
    }
  }

  Future<void> _rollback(File safety) async {
    try {
      await _replaceDatabaseFile(safety.path);
      await _appDb.database;
    } catch (_) {
      // Nothing more can be done; the safety copy stays on disk.
    }
  }

  Future<void> _replaceDatabaseFile(String sourcePath) {
    return _appDb.runExclusive((dbPath) async {
      for (final suffix in const ['-wal', '-shm', '-journal']) {
        final side = File('$dbPath$suffix');
        if (await side.exists()) await side.delete();
      }
      final staged = File('$dbPath.restoring');
      if (await staged.exists()) await staged.delete();
      await File(sourcePath).copy(staged.path);
      try {
        await staged.rename(dbPath);
      } on FileSystemException {
        // Some platforms cannot rename over an existing file.
        final old = File(dbPath);
        if (await old.exists()) await old.delete();
        await staged.rename(dbPath);
      }
    });
  }
}
