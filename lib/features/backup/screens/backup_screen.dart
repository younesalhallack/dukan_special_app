import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_models.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/ui/restart_widget.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/digits.dart';
import '../../../core/utils/file_size.dart';
import '../../../l10n/l10n.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/backup_providers.dart';

/// Export, restore and automatic internal backups.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  /// Runs [action] with a busy indicator and shows any error as a message.
  Future<void> _guard(Future<void> Function() action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _counts(AppLocalizations l10n, BackupInfo info, DigitStyle digits) {
    String n(int value) => Digits.localize('$value', digits);
    return l10n.dataCounts(
      n(info.products),
      n(info.customers),
      n(info.suppliers),
      n(info.invoices),
    );
  }

  // --- export ------------------------------------------------------------------

  Future<void> _exportCurrent() => _guard(() async {
        final l10n = context.l10n;
        final messenger = ScaffoldMessenger.of(context);
        final service = await ref.read(backupServiceProvider.future);
        final bytes = await service.createBackupBytes();
        final saved = await FilePicker.saveFile(
          dialogTitle: l10n.exportDialogTitle,
          fileName: service.exportFileName(),
          bytes: bytes,
        );
        if (saved == null) return; // cancelled
        await ref.read(settingsProvider.notifier).markExported(DateTime.now());
        messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone)));
      });

  Future<void> _exportInternal(BackupFileInfo backup) => _guard(() async {
        final l10n = context.l10n;
        final messenger = ScaffoldMessenger.of(context);
        final saved = await FilePicker.saveFile(
          dialogTitle: l10n.exportDialogTitle,
          fileName: backup.name,
          bytes: await backup.file.readAsBytes(),
        );
        if (saved == null) return;
        await ref.read(settingsProvider.notifier).markExported(DateTime.now());
        messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone)));
      });

  // --- restore -----------------------------------------------------------------

  Future<void> _restoreFromPicker() => _guard(() async {
        final l10n = context.l10n;
        final picked = await FilePicker.pickFile(dialogTitle: l10n.restoreBackup);
        if (picked == null) return;
        final service = await ref.read(backupServiceProvider.future);
        try {
          final staged = await service.stageIncoming(picked.readAsByteStream());
          await _confirmAndRestore(service, staged.path);
        } finally {
          await service.clearStaging();
        }
      });

  Future<void> _restoreInternal(BackupFileInfo backup) => _guard(() async {
        final service = await ref.read(backupServiceProvider.future);
        await _confirmAndRestore(service, backup.file.path);
      });

  /// Validates the file, shows what would change, and restores on approval.
  Future<void> _confirmAndRestore(BackupService service, String path) async {
    final info = await service.inspect(path); // throws a readable error
    final current = await service.currentInfo();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RestoreDialog(current: current, backup: info),
    );
    if (confirmed != true || !mounted) return;

    await service.restoreFrom(path);
    if (!mounted) return;
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.restoreDone),
        content: Text(l10n.restoreDoneNote),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (mounted) RestartWidget.restartApp(context);
  }

  Future<void> _deleteInternal(BackupFileInfo backup) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.deleteBackupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _guard(() async {
      final service = await ref.read(backupServiceProvider.future);
      await service.deleteBackup(backup.file);
      ref.invalidate(internalBackupsProvider);
    });
  }

  // --- build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final digits = settings?.digitStyle ?? DigitStyle.western;
    final current = ref.watch(currentBackupInfoProvider).value;
    final internal = ref.watch(internalBackupsProvider).value;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final lastExport = settings?.lastExportAt;
    final now = DateTime.now();
    final stale = isExportReminderDue(lastExport, now);
    final lastExportText = lastExport == null
        ? l10n.neverExported
        : l10n.lastExport(formatDateTime(lastExport.toLocal(), digits: digits));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backup)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            stale ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                            color: stale ? scheme.error : scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lastExportText,
                              style: textTheme.titleSmall?.copyWith(
                                color: stale ? scheme.error : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (current != null) ...[
                        const SizedBox(height: 10),
                        Text(l10n.currentData, style: textTheme.labelLarge),
                        Text(_counts(l10n, current, digits)),
                        Text(
                          l10n.dbSize(
                            Digits.localize(formatFileSize(current.sizeBytes), digits),
                          ),
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _exportCurrent,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(l10n.exportBackup),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _restoreFromPicker,
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.restoreBackup),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(l10n.exportHint, style: textTheme.bodySmall),
              ),
              const Divider(height: 32),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.autoBackup),
                subtitle: Text(l10n.autoBackupHint),
                value: settings?.autoBackupEnabled ?? true,
                onChanged: settings == null
                    ? null
                    : ref.read(settingsProvider.notifier).setAutoBackupEnabled,
              ),
              const SizedBox(height: 8),
              Text(l10n.internalBackups, style: textTheme.titleMedium),
              const SizedBox(height: 8),
              if (internal == null)
                const Center(child: CircularProgressIndicator())
              else if (internal.isEmpty)
                Text(l10n.noInternalBackups)
              else
                for (final backup in internal)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        backup.kind == BackupKind.auto
                            ? Icons.schedule_outlined
                            : Icons.shield_outlined,
                      ),
                      title: Text(formatDateTime(backup.modified, digits: digits)),
                      subtitle: Text(
                        '${backup.kind == BackupKind.auto ? l10n.backupAuto : l10n.backupSafety}'
                        '  •  ${Digits.localize(formatFileSize(backup.sizeBytes), digits)}',
                      ),
                      trailing: PopupMenuButton<String>(
                        enabled: !_busy,
                        onSelected: (value) {
                          switch (value) {
                            case 'restore':
                              _restoreInternal(backup);
                            case 'export':
                              _exportInternal(backup);
                            case 'delete':
                              _deleteInternal(backup);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'restore', child: Text(l10n.restore)),
                          PopupMenuItem(value: 'export', child: Text(l10n.export)),
                          PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compares what the shop has now with what the backup would bring back.
class _RestoreDialog extends ConsumerWidget {
  const _RestoreDialog({required this.current, required this.backup});

  final BackupInfo current;
  final BackupInfo backup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final digits = ref.watch(settingsProvider).value?.digitStyle ?? DigitStyle.western;
    final textTheme = Theme.of(context).textTheme;
    String n(int value) => Digits.localize('$value', digits);

    Widget block(String title, BackupInfo info) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleSmall),
          Text(l10n.dataCounts(
            n(info.products),
            n(info.customers),
            n(info.suppliers),
            n(info.invoices),
          )),
          Text(
            info.lastInvoiceAt == null
                ? l10n.noInvoicesYet
                : l10n.lastInvoice(formatDateTime(info.lastInvoiceAt!, digits: digits)),
            style: textTheme.bodySmall,
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(l10n.restoreConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.restoreWarning),
            const SizedBox(height: 16),
            block(l10n.currentData, current),
            const SizedBox(height: 12),
            block(l10n.backupData, backup),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.restore),
        ),
      ],
    );
  }
}
