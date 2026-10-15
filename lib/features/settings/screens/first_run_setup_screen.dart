import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../data/models/app_settings.dart';
import '../../../l10n/l10n.dart';
import '../providers/settings_providers.dart';

/// Shown on first launch: base currency, exchange rate and rounding step.
/// When saved, the app root switches to the home screen by itself.
class FirstRunSetupScreen extends ConsumerStatefulWidget {
  const FirstRunSetupScreen({super.key});

  @override
  ConsumerState<FirstRunSetupScreen> createState() =>
      _FirstRunSetupScreenState();
}

class _FirstRunSetupScreenState extends ConsumerState<FirstRunSetupScreen> {
  final _rateController = TextEditingController();
  Currency _base = Currency.syp;
  int _step = 100;
  bool _stepChosenByUser = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  void _onRateChanged(String text) {
    if (_stepChosenByUser) return;
    final rate = Money.parseDecimal(text);
    if (rate != null && rate > 0) {
      setState(() => _step = Money.suggestedRoundingStep(rate));
    }
  }

  Future<void> _submit() async {
    final rate = Money.parseDecimal(_rateController.text);
    if (rate == null || rate <= 0) {
      setState(() => _error = context.l10n.invalidRate);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(settingsProvider.notifier).completeSetup(
            baseCurrency: _base,
            exchangeRate: rate,
            sypRoundingStep: _step,
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
              selected: {_base},
              onSelectionChanged: (selection) =>
                  setState(() => _base = selection.first),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _rateController,
              textDirection: TextDirection.ltr,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.exchangeRateLabel,
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: _onRateChanged,
            ),
            const SizedBox(height: 24),
            Text(l10n.roundingStepLabel, style: titleStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final step in kSypRoundingSteps)
                  ChoiceChip(
                    label: Text(step == 1 ? l10n.noRounding : '$step'),
                    selected: _step == step,
                    onSelected: (_) => setState(() {
                      _step = step;
                      _stepChosenByUser = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.startUsing),
            ),
          ],
        ),
      ),
    );
  }
}
