import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/money.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/quantity.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/sale_transaction.dart';
import '../../../l10n/l10n.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../../suppliers/providers/suppliers_providers.dart';
import '../logic/purchase_format.dart';
import '../providers/purchases_providers.dart';

/// One purchase invoice with its lines and the rate it was recorded at.
/// A completed purchase can be voided (the quantities leave the stock).
class PurchaseDetailScreen extends ConsumerWidget {
  const PurchaseDetailScreen({super.key, required this.purchaseId});

  final int purchaseId;

  Future<void> _void(BuildContext context, WidgetRef ref, Purchase purchase) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.voidPurchase),
        content: Text(
          purchase.paymentType == PaymentType.credit
              ? '${l10n.voidPurchaseConfirm}\n\n${l10n.voidPurchaseCreditNote}'
              : l10n.voidPurchaseConfirm,
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
      await ref.read(purchaseRepositoryProvider).voidPurchase(purchaseId);
      ref.refreshPurchases();
      ref.refreshInventory();
      ref.refreshSuppliers();
      messenger.showSnackBar(SnackBar(content: Text(l10n.purchaseVoided)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(purchaseDetailsProvider(purchaseId));
    final details = async.value;
    final settings = ref.watch(settingsProvider).value;

    if (details == null || settings == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.purchaseDetails)),
        body: async.hasError
            ? Center(child: Text('${async.error}'))
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final purchase = details.purchase;
    final supplier = purchase.supplierId == null
        ? null
        : ref.watch(supplierByIdProvider(purchase.supplierId!)).value;
    final digits = settings.digitStyle;
    final textTheme = Theme.of(context).textTheme;
    String money(int amount) => Money.format(amount, purchase.currency, digits: digits);

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
      appBar: AppBar(title: Text(purchase.purchaseNumber)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (purchase.isVoided)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Chip(
                  label: Text(l10n.invoiceVoided),
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                ),
              ),
            row(l10n.supplierLabel, supplier?.name ?? l10n.noSupplierSelected),
            if (purchase.supplierInvoiceNumber != null)
              row(l10n.supplierInvoiceNumber, purchase.supplierInvoiceNumber!),
            row(l10n.purchaseDate, formatDateTime(purchase.purchaseDateLocal, digits: digits)),
            row(
              l10n.payment,
              purchase.paymentType == PaymentType.cash
                  ? l10n.paymentCash
                  : l10n.paymentCredit,
            ),
            row(
              l10n.exchangeRateUsed,
              Money.formatRate(purchase.exchangeRate, digits: digits),
            ),
            if (purchase.note != null) row(l10n.note, purchase.note!),
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
                            '${formatQuantity(item.quantity, digits: digits)} × ${money(item.unitCost)}',
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
            if (purchase.discountAmount > 0) ...[
              row(l10n.subtotal, money(purchase.subtotal)),
              row(l10n.discount, '- ${money(purchase.discountAmount)}'),
            ],
            row(
              l10n.total,
              purchaseAmountText(purchase.totalAmount, purchase, settings),
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (purchase.paymentType == PaymentType.credit) ...[
              const SizedBox(height: 8),
              row(l10n.paidNow, money(purchase.paidAmount)),
              row(
                l10n.payableAtPurchase,
                money(purchase.debtAmount),
                style: textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (!purchase.isVoided)
              OutlinedButton.icon(
                onPressed: () => _void(context, ref, purchase),
                icon: const Icon(Icons.cancel_outlined),
                label: Text(l10n.voidPurchase),
              ),
          ],
        ),
      ),
    );
  }
}
