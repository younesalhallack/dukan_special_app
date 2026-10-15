import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../core/utils/digits.dart';
import '../../../data/models/app_settings.dart';
import '../../../l10n/l10n.dart';
import '../../inventory/widgets/name_dialog.dart';
import '../providers/settings_providers.dart';

/// Exchange rate, base currency, rounding, dual-currency display, digits and
/// language. Backup / restore controls are added in a later step.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _editRate(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final l10n = context.l10n;
    final notifier = ref.read(settingsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final newRate = await showDialog<double>(
      context: context,
      builder: (_) => _RateDialog(initial: settings.rate),
    );
    if (newRate == null || !context.mounted) return;

    if (Money.isLargeRateChange(settings.rate, newRate)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.largeChangeTitle),
          content: Text(
            l10n.largeChangeMessage(
              Money.formatRate(newRate, digits: settings.digitStyle),
              Money.formatRate(settings.rate, digits: settings.digitStyle),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await notifier.updateExchangeRate(newRate);
    messenger.showSnackBar(SnackBar(content: Text(l10n.rateUpdated)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final notifier = ref.read(settingsProvider.notifier);
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: Text(l10n.currentRate),
                    subtitle: Text(
                      '1 ${Currency.usd.symbol} = '
                      '${Money.formatRate(settings.rate, digits: settings.digitStyle)} '
                      '${Currency.syp.symbol}',
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () => _editRate(context, ref, settings),
                      child: Text(l10n.edit),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(l10n.baseCurrency, style: titleStyle),
                const SizedBox(height: 8),
                SegmentedButton<Currency>(
                  segments: [
                    ButtonSegment(
                      value: Currency.syp,
                      label: Text(l10n.currencySyp),
                    ),
                    ButtonSegment(
                      value: Currency.usd,
                      label: Text(l10n.currencyUsd),
                    ),
                  ],
                  selected: {settings.baseCurrency ?? Currency.syp},
                  onSelectionChanged: (s) => notifier.setBaseCurrency(s.first),
                ),
                const SizedBox(height: 20),
                Text(l10n.roundingStepLabel, style: titleStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final step in kSypRoundingSteps)
                      ChoiceChip(
                        label: Text(step == 1 ? l10n.noRounding : '$step'),
                        selected: settings.sypRoundingStep == step,
                        onSelected: (_) => notifier.setSypRoundingStep(step),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.showDualCurrency),
                  value: settings.showDualCurrency,
                  onChanged: notifier.setShowDualCurrency,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.allowNegativeStock),
                  value: settings.allowNegativeStock,
                  onChanged: notifier.setAllowNegativeStock,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.storeName),
                  subtitle: Text(
                    settings.storeName.isEmpty ? '—' : settings.storeName,
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final name = await showNameDialog(
                      context,
                      title: l10n.storeName,
                      label: l10n.storeName,
                      initial: settings.storeName,
                    );
                    if (name != null) await notifier.setStoreName(name);
                  },
                ),
                const SizedBox(height: 8),
                Text(l10n.digitStyle, style: titleStyle),
                const SizedBox(height: 8),
                SegmentedButton<DigitStyle>(
                  segments: [
                    ButtonSegment(
                      value: DigitStyle.western,
                      label: Text(l10n.digitsWestern),
                    ),
                    ButtonSegment(
                      value: DigitStyle.arabicIndic,
                      label: Text(l10n.digitsArabicIndic),
                    ),
                  ],
                  selected: {settings.digitStyle},
                  onSelectionChanged: (s) => notifier.setDigitStyle(s.first),
                ),
                const SizedBox(height: 20),
                Text(l10n.language, style: titleStyle),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'ar',
                      label: Text(l10n.languageArabic),
                    ),
                    ButtonSegment(
                      value: 'en',
                      label: Text(l10n.languageEnglish),
                    ),
                  ],
                  selected: {settings.language},
                  onSelectionChanged: (s) => notifier.setLanguage(s.first),
                ),
              ],
            ),
    );
  }
}

class _RateDialog extends StatefulWidget {
  const _RateDialog({required this.initial});

  final double initial;

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: Money.formatRate(widget.initial).replaceAll(',', ''),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final rate = Money.parseDecimal(_controller.text);
    if (rate == null || rate <= 0) {
      setState(() => _error = context.l10n.invalidRate);
      return;
    }
    Navigator.pop(context, rate);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.updateRate),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textDirection: TextDirection.ltr,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: l10n.exchangeRateLabel,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
