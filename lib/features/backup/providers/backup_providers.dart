import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/backup/backup_models.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/database/database_providers.dart';

/// The app's private folder where internal backups live.
final backupBaseDirProvider = FutureProvider<Directory>((ref) {
  return getApplicationDocumentsDirectory();
});

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final dir = await ref.watch(backupBaseDirProvider.future);
  return BackupService(appDb: ref.watch(appDatabaseProvider), baseDir: dir);
});

/// What the live database holds (counts, size, last invoice).
final currentBackupInfoProvider = FutureProvider.autoDispose<BackupInfo>((ref) async {
  final service = await ref.watch(backupServiceProvider.future);
  return service.currentInfo();
});

/// Automatic and safety backups kept inside the app, newest first.
final internalBackupsProvider =
    FutureProvider.autoDispose<List<BackupFileInfo>>((ref) async {
  final service = await ref.watch(backupServiceProvider.future);
  return service.listBackups();
});
