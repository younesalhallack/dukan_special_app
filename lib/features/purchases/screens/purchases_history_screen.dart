import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/digits.dart';
import '../../../data/models/sale_transaction.dart';
import '../../../l10n/l10n.dart';
import '../../settings/providers/settings_providers.dart';
import '../logic/purchases_summary.dart';
import '../providers/purchases_providers.dart';
import 'purchase_detail_screen.dart';
import 'purchase_screen.dart';

/// Purchase invoices of one day with a summary. The summary converts each
/// purchase with its own exchange rate.
class PurchasesHistoryScreen extends ConsumerWidget {
  const PurchasesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final digits = settings?.digitStyle ?? DigitStyle.western;
    final day = ref.watch(purchasesDayProvider);
    final dayNotifier = ref.read(purchasesDayProvider.notifier);
    final async = ref.watch(purchasesProvider);
    final purchases = async.value;

    Future<void> pickDay() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)),
      );
      if (picked != null) dayNotifier.setDay(picked);
    }

    Widget body;
    if (purchases == null) {
      body = async.hasError
          ? Center(child: Text('${async.error}'))
          : const Center(child: CircularProgressIndicator());
    } else {
      final base = settings?.baseCurrency ?? Currency.usd;
      final summary = PurchasesSummary.fromPurchases(purchases, base);
      body = ListView(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.purchasesCount(Digits.localize('${summary.count}', digits)),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final entry in summary.totalsByCurrency.entries)
                    Text(Money.format(entry.value, entry.key, digits: digits)),
                  if (summary.totalsByCurrency.length > 1) ...[
                    const Divider(height: 20),
                    Text(l10n.totalPurchasesBase),
                    Text(
                      Money.format(summary.totalInBase, base, digits: digits),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (purchases.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(l10n.noPurchases)),
            ),
          for (final purchase in purchases)
            ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PurchaseDetailScreen(purchaseId: purchase.id),
                ),
              ),
              title: Row(
                children: [
                  Flexible(child: Text(purchase.purchaseNumber)),
                  if (purchase.isVoided) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(l10n.invoiceVoided),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                '${formatTime(purchase.purchaseDateLocal, digits: digits)}  •  '
                '${purchase.paymentType == PaymentType.cash ? l10n.paymentCash : l10n.paymentCredit}'
                '${purchase.supplierInvoiceNumber == null ? '' : '  •  ${purchase.supplierInvoiceNumber}'}',
              ),
              trailing: Text(
                Money.format(purchase.totalAmount, purchase.currency, digits: digits),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: purchase.isVoided ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.purchasesHistory),
        actions: [
          TextButton(onPressed: dayNotifier.today, child: Text(l10n.today)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PurchaseScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.newPurchase),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => dayNotifier.shift(-1),
              ),
              TextButton.icon(
                onPressed: pickDay,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(formatDate(day, digits: digits)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => dayNotifier.shift(1),
              ),
            ],
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
