import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_models.dart';
import '../../../core/utils/digits.dart';
import '../../../l10n/l10n.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/backup_providers.dart';
import '../screens/backup_screen.dart';

/// Shown on the home screen when the shop has data but no backup was exported
/// for a week. Disappears by itself after an export.
class BackupReminderCard extends ConsumerWidget {
  const BackupReminderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final info = ref.watch(currentBackupInfoProvider).value;
    if (settings == null || info == null) return const SizedBox.shrink();

    final hasData = info.products + info.invoices + info.customers + info.purchases > 0;
    final now = DateTime.now();
    if (!hasData || !isExportReminderDue(settings.lastExportAt, now)) {
      return const SizedBox.shrink();
    }

    final last = settings.lastExportAt;
    final subtitle = last == null
        ? l10n.neverExported
        : l10n.exportOld(
            Digits.localize('${now.difference(last).inDays}', settings.digitStyle),
          );

    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded),
        title: Text(l10n.backupReminder),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
        ),
      ),
    );
  }
}
