import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/money.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/quantity.dart';
import '../../../data/models/sale_transaction.dart';
import '../../../l10n/l10n.dart';
import '../../customers/providers/customers_providers.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../logic/invoice_format.dart';
import '../providers/sales_providers.dart';

/// One invoice with its lines, the frozen exchange rate and the profit.
/// A completed invoice can be voided (stock is restored).
class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final int invoiceId;

  Future<void> _void(
    BuildContext context,
    WidgetRef ref,
    SaleTransaction invoice,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.voidInvoice),
        content: Text(
          invoice.paymentType == PaymentType.credit
              ? '${l10n.voidConfirm}\n\n${l10n.voidCreditNote}'
              : l10n.voidConfirm,
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
    try {
      await ref.read(transactionRepositoryProvider).voidInvoice(invoiceId);
      ref.invalidate(invoiceDetailsProvider(invoiceId));
      ref.invalidate(invoicesProvider);
      ref.refreshInventory();
      ref.refreshCustomers();
      messenger.showSnackBar(SnackBar(content: Text(l10n.voidDone)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(invoiceDetailsProvider(invoiceId));
    final details = async.value;
    final settings = ref.watch(settingsProvider).value;

    if (details == null || settings == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.invoiceDetails)),
        body: async.hasError
            ? Center(child: Text('${async.error}'))
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final invoice = details.transaction;
    final customer = invoice.customerId == null
        ? null
        : ref.watch(customerByIdProvider(invoice.customerId!)).value;
    final digits = settings.digitStyle;
    final textTheme = Theme.of(context).textTheme;
    String money(int amount) => Money.format(amount, invoice.currency, digits: digits);

    Widget row(String label, String value, {TextStyle? style}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Flexible(child: Text(value, style: style, textAlign: TextAlign.end)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(invoice.invoiceNumber)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (settings.storeName.isNotEmpty)
              Text(settings.storeName, style: textTheme.titleLarge),
            if (invoice.isVoided)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Chip(
                  label: Text(l10n.invoiceVoided),
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                ),
              ),
            const SizedBox(height: 8),
            row(l10n.date, formatDateTime(invoice.createdAtLocal, digits: digits)),
            row(
              l10n.payment,
              invoice.paymentType == PaymentType.cash
                  ? l10n.paymentCash
                  : l10n.paymentCredit,
            ),
            if (customer != null) row(l10n.customerLabel, customer.name),
            row(
              l10n.exchangeRateUsed,
              Money.formatRate(invoice.exchangeRate, digits: digits),
            ),
            const Divider(height: 24),
            for (final item in details.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName, style: textTheme.titleSmall),
                          Text(
                            '${formatQuantity(item.quantity, digits: digits)} × ${money(item.unitPrice)}',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(money(item.lineTotal)),
                  ],
                ),
              ),
            const Divider(height: 24),
            if (invoice.discountAmount > 0) ...[
              row(l10n.subtotal, money(invoice.subtotal)),
              row(l10n.discount, '- ${money(invoice.discountAmount)}'),
            ],
            row(
              l10n.total,
              invoiceAmountText(invoice.totalAmount, invoice, settings),
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (invoice.paymentType == PaymentType.credit) ...[
              row(l10n.paidNow, money(invoice.paidAmount)),
              row(
                l10n.debtAtSale,
                money(invoice.debtAmount),
                style: textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
            ],
            row(l10n.cost, money(invoice.totalCost)),
            row(l10n.profit, money(invoice.profit)),
            const SizedBox(height: 24),
            if (!invoice.isVoided)
              OutlinedButton.icon(
                onPressed: () => _void(context, ref, invoice),
                icon: const Icon(Icons.cancel_outlined),
                label: Text(l10n.voidInvoice),
              ),
          ],
        ),
      ),
    );
  }
}
