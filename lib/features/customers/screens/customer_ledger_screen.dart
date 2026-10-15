import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/digits.dart';
import '../../../data/models/app_settings.dart';
import '../../../l10n/l10n.dart';
import '../../pos/screens/invoice_detail_screen.dart';
import '../../settings/providers/settings_providers.dart';
import '../logic/ledger_builder.dart';
import '../providers/customers_providers.dart';
import '../widgets/add_payment_dialog.dart';
import 'customer_form_screen.dart';

/// A customer's statement: balances, invoices on credit and payments, with
/// the running balance after each entry.
class CustomerLedgerScreen extends ConsumerWidget {
  const CustomerLedgerScreen({super.key, required this.customerId});

  final int customerId;

  String _statementText(
    AppLocalizations l10n,
    CustomerLedger ledger,
    AppSettings settings,
  ) {
    final base = settings.baseCurrency ?? Currency.syp;
    final lines = <String>[
      if (settings.storeName.isNotEmpty) settings.storeName,
      l10n.statementHeader(ledger.customer.name),
      l10n.statementDate(formatDate(DateTime.now(), digits: settings.digitStyle)),
    ];
    for (final currency in [base, base.other]) {
      final value = ledger.balance.of(currency);
      if (value > 0) {
        lines.add(
          '${l10n.statementOwed}: ${Money.format(value, currency, digits: settings.digitStyle)}',
        );
      } else if (value < 0) {
        lines.add(
          '${l10n.statementCredit}: ${Money.format(-value, currency, digits: settings.digitStyle)}',
        );
      }
    }
    if (ledger.balance.isZero) lines.add(l10n.statementSettled);
    return lines.join('\n');
  }

  Future<void> _voidPayment(
    BuildContext context,
    WidgetRef ref,
    int paymentId,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.voidPayment),
        content: Text(l10n.voidPaymentConfirm),
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
      await ref.read(customerPaymentRepositoryProvider).voidPayment(paymentId);
      ref.refreshCustomers();
      messenger.showSnackBar(SnackBar(content: Text(l10n.paymentVoided)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(customerLedgerProvider(customerId));
    final ledger = async.value;
    final settings = ref.watch(settingsProvider).value;

    if (ledger == null || settings == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.hasError
            ? Center(child: Text('${async.error}'))
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final digits = settings.digitStyle;
    final base = settings.baseCurrency ?? Currency.syp;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    String money(int value, Currency c) => Money.format(value, c, digits: digits);

    final balanceLines = <Widget>[];
    for (final currency in [base, base.other]) {
      final value = ledger.balance.of(currency);
      if (value == 0) continue;
      balanceLines.add(
        Text(
          value > 0
              ? '${l10n.owes}: ${money(value, currency)}'
              : '${l10n.creditInFavor}: ${money(-value, currency)}',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: value > 0 ? scheme.error : scheme.primary,
          ),
        ),
      );
    }
    if (balanceLines.isEmpty) {
      balanceLines.add(Text(l10n.noDebt, style: textTheme.titleLarge));
    }

    final entries = ledger.entries.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(ledger.customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.editCustomer,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CustomerFormScreen(customer: ledger.customer),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ledger.customer.phone != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(ledger.customer.phone!),
                    ),
                  if (ledger.customer.notes != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(ledger.customer.notes!, style: textTheme.bodySmall),
                    ),
                  Text(l10n.balance, style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  ...balanceLines,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: ledger.balance.owes
                        ? () => showAddPaymentDialog(
                              context,
                              customer: ledger.customer,
                              balance: ledger.balance,
                            )
                        : null,
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(l10n.recordPayment),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                      ClipboardData(text: _statementText(l10n, ledger, settings)),
                    );
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.statementCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(l10n.copyStatement),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(l10n.noEntries)),
            ),
          for (final entry in entries)
            _EntryTile(
              entry: entry,
              digits: digits,
              onVoidPayment: (id) => _voidPayment(context, ref, id),
              onOpenInvoice: (id) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => InvoiceDetailScreen(invoiceId: id),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.digits,
    required this.onVoidPayment,
    required this.onOpenInvoice,
  });

  final LedgerEntry entry;
  final DigitStyle digits;
  final ValueChanged<int> onVoidPayment;
  final ValueChanged<int> onOpenInvoice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final voided = entry.isVoided;
    final isInvoice = entry.kind == LedgerEntryKind.invoice;
    String money(int value, Currency c) => Money.format(value, c, digits: digits);

    final strike = voided ? TextDecoration.lineThrough : null;
    final muted = voided ? Theme.of(context).disabledColor : null;

    final details = <String>[formatDateTime(entry.date, digits: digits)];
    if (isInvoice) {
      final invoice = entry.invoice!;
      if (invoice.paidAmount > 0) {
        details.add(
          '${l10n.paidNow}: ${money(invoice.paidAmount, invoice.currency)}',
        );
      }
    } else {
      final payment = entry.payment!;
      if (payment.currency != payment.appliedCurrency) {
        details.add(l10n.ledgerPaidIn(money(payment.amount, payment.currency)));
        details.add(
          '${l10n.exchangeRateUsed}: ${Money.formatRate(payment.exchangeRate, digits: digits)}',
        );
      }
      if (payment.note != null) details.add(payment.note!);
    }
    if (voided) details.add(l10n.invoiceVoided);

    final deltaColor =
        voided ? muted : (entry.delta > 0 ? scheme.error : Colors.green.shade700);
    final deltaText = entry.delta > 0
        ? '+ ${money(entry.delta, entry.currency)}'
        : entry.delta < 0
            ? '− ${money(-entry.delta, entry.currency)}'
            : money(0, entry.currency);

    return ListTile(
      leading: Icon(
        isInvoice ? Icons.receipt_long_outlined : Icons.payments_outlined,
        color: muted,
      ),
      title: Text(
        isInvoice
            ? l10n.ledgerInvoice(entry.invoice!.invoiceNumber)
            : l10n.ledgerPayment,
        style: TextStyle(decoration: strike, color: muted),
      ),
      subtitle: Text(details.join('  •  ')),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            deltaText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: deltaColor,
              decoration: strike,
            ),
          ),
          if (entry.balanceAfter != null)
            Text(
              money(entry.balanceAfter!, entry.currency),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      onTap: () {
        if (isInvoice) {
          onOpenInvoice(entry.invoice!.id);
        } else if (!voided) {
          onVoidPayment(entry.payment!.id);
        }
      },
    );
  }
}
