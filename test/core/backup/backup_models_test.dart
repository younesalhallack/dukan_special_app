import 'package:flutter_test/flutter_test.dart';

import 'package:dukan_special_app/core/backup/backup_models.dart';
import 'package:dukan_special_app/core/database/migrations.dart';
import 'package:dukan_special_app/core/database/schema.dart';
import 'package:dukan_special_app/core/utils/file_size.dart';

void main() {
  group('requiredTablesAt', () {
    test('the current version requires every table of the schema', () {
      expect(requiredTablesAt(currentDbVersion), requiredTables.toSet());
    });

    test('older versions require fewer tables', () {
      expect(requiredTablesAt(1), hasLength(9));
      expect(requiredTablesAt(3), requiredTablesAt(1));
      expect(requiredTablesAt(1), isNot(contains(Tables.suppliers)));
      expect(
        requiredTablesAt(4),
        containsAll([
          Tables.suppliers,
          Tables.purchases,
          Tables.purchaseItems,
          Tables.supplierPayments,
        ]),
      );
    });
  });

  group('backupFileName', () {
    test('uses a sortable date and time', () {
      expect(
        backupFileName(DateTime(2026, 10, 18, 15, 30, 7)),
        'dukan_backup_2026-10-18_1530.db',
      );
      expect(
        backupFileName(DateTime(2026, 3, 5, 9, 7)),
        'dukan_backup_2026-03-05_0907.db',
      );
    });

    test('seconds and a prefix for internal copies', () {
      expect(
        backupFileName(DateTime(2026, 10, 18, 15, 30, 7), prefix: 'auto', withSeconds: true),
        'auto_2026-10-18_153007.db',
      );
    });
  });

  group('isAutoBackupDue', () {
    final now = DateTime(2026, 10, 18, 9);

    test('never backed up is due', () {
      expect(isAutoBackupDue(null, now), isTrue);
    });

    test('already done today is not due, even late at night yesterday is', () {
      expect(isAutoBackupDue(DateTime(2026, 10, 18, 0, 5), now), isFalse);
      expect(isAutoBackupDue(DateTime(2026, 10, 17, 23, 59), now), isTrue);
    });

    test('a last backup dated in the future (clock moved) is due on another day', () {
      expect(isAutoBackupDue(DateTime(2026, 11, 1), now), isTrue);
    });
  });

  group('isExportReminderDue', () {
    final now = DateTime(2026, 10, 18, 9);

    test('never exported is due', () {
      expect(isExportReminderDue(null, now), isTrue);
    });

    test('due from 7 days on', () {
      expect(isExportReminderDue(now.subtract(const Duration(days: 6)), now), isFalse);
      expect(isExportReminderDue(now.subtract(const Duration(days: 7)), now), isTrue);
      expect(isExportReminderDue(now.subtract(const Duration(days: 30)), now), isTrue);
    });
  });

  test('formatFileSize', () {
    expect(formatFileSize(512), '512 B');
    expect(formatFileSize(1536), '1.5 KB');
    expect(formatFileSize(5 * 1024 * 1024), '5.0 MB');
  });
}
