import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_models.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/backup_providers.dart';

/// Makes the daily automatic backup once per day, in the background, when the
/// configured app is opened. Failures are ignored: a missed automatic backup
/// must never get in the way of the shop.
class AutoBackupRunner extends ConsumerStatefulWidget {
  const AutoBackupRunner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoBackupRunner> createState() => _AutoBackupRunnerState();
}

class _AutoBackupRunnerState extends ConsumerState<AutoBackupRunner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      final settings = await ref.read(settingsProvider.future);
      if (!mounted || !settings.isConfigured || !settings.autoBackupEnabled) return;
      final now = DateTime.now();
      if (!isAutoBackupDue(settings.lastAutoBackupAt, now)) return;
      final service = await ref.read(backupServiceProvider.future);
      await service.createAutoBackup();
      if (!mounted) return;
      await ref.read(settingsProvider.notifier).markAutoBackup(now);
      ref.invalidate(internalBackupsProvider);
    } catch (_) {
      // Ignored on purpose, see the class comment.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
