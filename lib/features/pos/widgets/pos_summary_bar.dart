import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../data/models/app_settings.dart';
import '../../../l10n/l10n.dart';
import '../logic/cart_calculator.dart';
import '../providers/cart_provider.dart';
import 'pos_dialogs.dart';

/// Bottom bar of the POS screen: invoice currency, discount, total and the
/// checkout button.
class PosSummaryBar extends ConsumerWidget {
  const PosSummaryBar({
    super.key,
    required this.totals,
    required this.settings,
    required this.onCheckout,
  });

  final CartTotals totals;
  final AppSettings settings;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(cartProvider.notifier);
    final digits = settings.digitStyle;
    final currency = totals.currency;
    final textTheme = Theme.of(context).textTheme;

    String money(int amount) => Money.format(amount, currency, digits: digits);

    final secondary = Money.salePriceIn(
      amountMinor: totals.total,
      from: currency,
      to: currency.other,
      rate: totals.rate,
      sypStep: settings.sypRoundingStep,
    );

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.invoiceCurrency)),
                  SegmentedButton<Currency>(
                    segments: [
                      ButtonSegment(value: Currency.syp, label: Text(Currency.syp.symbol)),
                      ButtonSegment(value: Currency.usd, label: Text(Currency.usd.symbol)),
                    ],
                    selected: {currency},
                    onSelectionChanged: (s) => notifier.setCurrency(s.first),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (totals.discount > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.subtotal),
                    Text(money(totals.subtotal)),
                  ],
                ),
              InkWell(
                onTap: totals.isEmpty
                    ? null
                    : () async {
                        final value = await promptDiscount(
                          context,
                          currency: currency,
                          max: totals.subtotal,
                          current: totals.discount,
                        );
                        if (value != null) notifier.setDiscount(value);
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(l10n.discount),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined, size: 14),
                        ],
                      ),
                      Text(totals.discount > 0 ? '- ${money(totals.discount)}' : '—'),
                    ],
                  ),
                ),
              ),
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.total, style: textTheme.titleMedium),
                  Text(
                    money(totals.total),
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (settings.showDualCurrency)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    Money.format(secondary, currency.other, digits: digits),
                    style: textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: totals.isEmpty ? null : onCheckout,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.checkout),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
