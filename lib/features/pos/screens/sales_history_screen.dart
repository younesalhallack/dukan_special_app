import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/digits.dart';
import '../../../data/models/sale_transaction.dart';
import '../../../l10n/l10n.dart';
import '../../settings/providers/settings_providers.dart';
import '../logic/sales_summary.dart';
import '../providers/sales_providers.dart';
import 'invoice_detail_screen.dart';

/// Invoices of one day with a summary. The summary converts each invoice
/// with its own frozen exchange rate.
class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final digits = settings?.digitStyle ?? DigitStyle.western;
    final day = ref.watch(salesDayProvider);
    final dayNotifier = ref.read(salesDayProvider.notifier);
    final async = ref.watch(invoicesProvider);
    final invoices = async.value;

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
    if (invoices == null) {
      body = async.hasError
          ? Center(child: Text('${async.error}'))
          : const Center(child: CircularProgressIndicator());
    } else {
      final base = settings?.baseCurrency ?? Currency.syp;
      final summary = SalesSummary.fromInvoices(invoices, base);
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
                    l10n.salesCount(Digits.localize('${summary.count}', digits)),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final entry in summary.totalsByCurrency.entries)
                    Text(Money.format(entry.value, entry.key, digits: digits)),
                  if (summary.totalsByCurrency.isNotEmpty) ...[
                    const Divider(height: 20),
                    Text(l10n.totalSalesBase),
                    Text(
                      Money.format(summary.totalInBase, base, digits: digits),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.profit}: ${Money.format(summary.profitInBase, base, digits: digits)}',
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(l10n.noInvoices)),
            ),
          for (final invoice in invoices)
            ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id),
                ),
              ),
              title: Row(
                children: [
                  Flexible(child: Text(invoice.invoiceNumber)),
                  if (invoice.isVoided) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(l10n.invoiceVoided),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                '${formatTime(invoice.createdAtLocal, digits: digits)}  •  '
                '${invoice.paymentType == PaymentType.cash ? l10n.paymentCash : l10n.paymentCredit}',
              ),
              trailing: Text(
                Money.format(invoice.totalAmount, invoice.currency, digits: digits),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: invoice.isVoided ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.salesHistory),
        actions: [
          TextButton(onPressed: dayNotifier.today, child: Text(l10n.today)),
        ],
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
