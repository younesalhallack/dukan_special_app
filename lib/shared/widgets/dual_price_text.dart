import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/currency.dart';
import '../../core/currency/money.dart';
import '../../features/settings/providers/settings_providers.dart';

/// Shows one amount in both currencies (base currency first), using the
/// current exchange rate. SYP amounts derived from USD are rounded up to the
/// configured step. With "dual currency" turned off, only the base currency
/// is shown.
class DualPriceText extends ConsumerWidget {
  const DualPriceText({
    super.key,
    required this.amountMinor,
    required this.currency,
    this.style,
  });

  final int amountMinor;
  final Currency currency;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null || !settings.isConfigured) {
      return Text(Money.format(amountMinor, currency), style: style);
    }

    String show(Currency target) {
      final value = Money.salePriceIn(
        amountMinor: amountMinor,
        from: currency,
        to: target,
        rate: settings.rate,
        sypStep: settings.sypRoundingStep,
      );
      return Money.format(value, target, digits: settings.digitStyle);
    }

    final first = settings.baseCurrency!;
    final text = settings.showDualCurrency
        ? '${show(first)}  •  ${show(first.other)}'
        : show(first);
    return Text(text, style: style);
  }
}
