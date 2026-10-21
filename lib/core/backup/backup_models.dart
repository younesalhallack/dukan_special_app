import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../database/schema.dart';

/// The tables a valid database of schema [version] must contain. Keep it in
/// step with the migrations: a test checks that the current version matches
/// `requiredTables`.
Set<String> requiredTablesAt(int version) {
  final tables = <String>{
    Tables.settings,
    Tables.exchangeRateHistory,
    Tables.categories,
    Tables.products,
    Tables.customers,
    Tables.transactions,
    Tables.transactionItems,
    Tables.customerPayments,
    Tables.stockMovements,
  };
  if (version >= 4) {
    tables.addAll({
      Tables.suppliers,
      Tables.purchases,
      Tables.purchaseItems,
      Tables.supplierPayments,
    });
  }
  return tables;
}

String _two(int value) => value.toString().padLeft(2, '0');

/// `dukan_backup_2026-10-18_1530.db` (or `..._153007.db` with seconds).
String backupFileName(
  DateTime time, {
  String prefix = 'dukan_backup',
  bool withSeconds = false,
}) {
  final date = '${time.year}-${_two(time.month)}-${_two(time.day)}';
  final clock = '${_two(time.hour)}${_two(time.minute)}${withSeconds ? _two(time.second) : ''}';
  return '${prefix}_${date}_$clock.db';
}

/// True when the daily automatic backup has not run today yet.
bool isAutoBackupDue(DateTime? lastAt, DateTime now) {
  if (lastAt == null) return true;
  final last = lastAt.toLocal();
  final today = now.toLocal();
  final sameDay =
      last.year == today.year && last.month == today.month && last.day == today.day;
  if (sameDay) return false;
  return true;
}

/// True when no backup was exported for [days] days (or never).
bool isExportReminderDue(DateTime? lastExportAt, DateTime now, {int days = 7}) {
  if (lastExportAt == null) return true;
  return now.difference(lastExportAt) >= Duration(days: days);
}

/// What is inside a database: used to show the user what a restore would
/// bring back, next to what he has now.
class BackupInfo {
  const BackupInfo({
    required this.userVersion,
    required this.sizeBytes,
    required this.products,
    required this.customers,
    required this.suppliers,
    required this.invoices,
    required this.purchases,
    required this.lastInvoiceAt,
  });

  final int userVersion;
  final int sizeBytes;
  final int products;
  final int customers;
  final int suppliers;

  /// Completed sales invoices.
  final int invoices;

  /// Completed purchase invoices.
  final int purchases;
  final DateTime? lastInvoiceAt;

  static Future<BackupInfo> read(
    DatabaseExecutor db, {
    required int userVersion,
    required int sizeBytes,
  }) async {
    Future<int> count(String sql) async {
      final rows = await db.rawQuery(sql);
      return (rows.first.values.first as num?)?.toInt() ?? 0;
    }

    final lastRows = await db.rawQuery(
      'SELECT MAX(created_at) AS last FROM ${Tables.transactions}',
    );
    final last = lastRows.first['last'] as String?;
    return BackupInfo(
      userVersion: userVersion,
      sizeBytes: sizeBytes,
      products: await count('SELECT COUNT(*) FROM ${Tables.products}'),
      customers: await count('SELECT COUNT(*) FROM ${Tables.customers}'),
      suppliers: userVersion >= 4
          ? await count('SELECT COUNT(*) FROM ${Tables.suppliers}')
          : 0,
      invoices: await count(
        "SELECT COUNT(*) FROM ${Tables.transactions} WHERE status = 'completed'",
      ),
      purchases: userVersion >= 4
          ? await count(
              "SELECT COUNT(*) FROM ${Tables.purchases} WHERE status = 'completed'",
            )
          : 0,
      lastInvoiceAt: last == null ? null : DateTime.tryParse(last)?.toLocal(),
    );
  }
}

enum BackupKind { auto, safety }

/// An internal backup file (automatic, or the safety copy of a restore).
class BackupFileInfo {
  const BackupFileInfo({
    required this.file,
    required this.sizeBytes,
    required this.modified,
    required this.kind,
  });

  final File file;
  final int sizeBytes;
  final DateTime modified;
  final BackupKind kind;

  String get name => p.basename(file.path);
}
