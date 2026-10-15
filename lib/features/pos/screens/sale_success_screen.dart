import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../settings/providers/settings_providers.dart';
import '../logic/invoice_format.dart';
import '../providers/sales_providers.dart';
import 'invoice_detail_screen.dart';

/// Shown after a sale is saved. "New invoice" returns to the POS screen.
class SaleSuccessScreen extends ConsumerWidget {
  const SaleSuccessScreen({super.key, required this.invoiceId});

  final int invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final details = ref.watch(invoiceDetailsProvider(invoiceId)).value;
    final settings = ref.watch(settingsProvider).value;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.saleDone),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                if (details != null && settings != null) ...[
                  Text(
                    l10n.invoiceNumberLabel(details.transaction.invoiceNumber),
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    invoiceAmountText(
                      details.transaction.totalAmount,
                      details.transaction,
                      settings,
                    ),
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(l10n.newInvoice),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => InvoiceDetailScreen(invoiceId: invoiceId),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(l10n.invoiceDetails),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
