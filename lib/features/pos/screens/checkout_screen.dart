import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/money.dart';
import '../../../core/errors/error_messages.dart';
import '../../../data/models/checkout_request.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/sale_transaction.dart';
import '../../../l10n/l10n.dart';
import '../../customers/providers/customers_providers.dart';
import '../../customers/widgets/customer_picker.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/cart_provider.dart';
import '../providers/sales_providers.dart';
import 'sale_success_screen.dart';

/// Payment step: cash, or credit (on the customer's account, optionally with
/// a down payment). The exchange rate used for the invoice is the one in
/// effect at the moment "Confirm sale" is pressed.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _received = TextEditingController();
  final _paidNow = TextEditingController();
  PaymentType _type = PaymentType.cash;
  Customer? _customer;
  bool _busy = false;

  @override
  void dispose() {
    _received.dispose();
    _paidNow.dispose();
    super.dispose();
  }

  Future<void> _chooseCustomer() async {
    final customer = await pickCustomer(context);
    if (customer != null && mounted) setState(() => _customer = customer);
  }

  Future<void> _confirm() async {
    final l10n = context.l10n;
    final totals = ref.read(cartTotalsProvider);
    final settings = ref.read(settingsProvider).value;
    final cart = ref.read(cartProvider);
    if (totals == null || settings == null || totals.isEmpty) return;

    final isCredit = _type == PaymentType.credit;
    int? paid;
    if (isCredit) {
      final customer = _customer;
      if (customer == null) return;
      final text = _paidNow.text.trim();
      paid = text.isEmpty ? 0 : Money.parse(text, totals.currency);
      if (paid == null || paid < 0 || paid > totals.total) return;
    }

    // Warn when the cart takes the stock below zero (if the shop allows it).
    final exceeds = cart.lines.any((line) => line.quantity > line.stockQuantity);
    if (exceeds && settings.allowNegativeStock) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(l10n.exceedsStockWarning),
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
      if (proceed != true || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final id = await ref.read(transactionRepositoryProvider).checkout(
            CheckoutRequest(
              currency: totals.currency,
              exchangeRate: totals.rate,
              lines: totals.lines,
              discountAmount: totals.discount,
              paymentType: _type,
              paidAmount: isCredit ? paid : null,
              customerId: isCredit ? _customer!.id : null,
            ),
          );
      ref.read(cartProvider.notifier).clear();
      ref.refreshInventory();
      ref.refreshCustomers();
      ref.invalidate(invoicesProvider);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => SaleSuccessScreen(invoiceId: id)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totals = ref.watch(cartTotalsProvider);
    final settings = ref.watch(settingsProvider).value;

    if (totals == null || settings == null || totals.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.checkout)),
        body: Center(child: Text(l10n.cartEmpty)),
      );
    }

    final digits = settings.digitStyle;
    final currency = totals.currency;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    String money(int amount) => Money.format(amount, currency, digits: digits);
    final isCredit = _type == PaymentType.credit;

    // Cash: amount received and change.
    final receivedText = _received.text.trim();
    final received = receivedText.isEmpty ? null : Money.parse(receivedText, currency);
    final invalidReceived = receivedText.isNotEmpty && received == null;
    final shortfall = received != null && received < totals.total;
    final change =
        (received != null && received >= totals.total) ? received - totals.total : null;

    // Credit: down payment and the debt that remains.
    final paidText = _paidNow.text.trim();
    final paid = paidText.isEmpty ? 0 : Money.parse(paidText, currency);
    final invalidPaid = paid == null || paid > totals.total;
    final remainingDebt =
        (paid == null || paid > totals.total) ? null : totals.total - paid;

    final secondary = Money.salePriceIn(
      amountMinor: totals.total,
      from: currency,
      to: currency.other,
      rate: totals.rate,
      sypStep: settings.sypRoundingStep,
    );

    final canConfirm = !_busy &&
        (isCredit ? (_customer != null && !invalidPaid) : (!invalidReceived && !shortfall));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkout)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.total, style: textTheme.titleMedium),
            Text(
              money(totals.total),
              style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (settings.showDualCurrency)
              Text(
                Money.format(secondary, currency.other, digits: digits),
                style: textTheme.titleMedium,
              ),
            if (totals.discount > 0) ...[
              const SizedBox(height: 8),
              Text('${l10n.discount}: ${money(totals.discount)}'),
            ],
            const SizedBox(height: 20),
            SegmentedButton<PaymentType>(
              segments: [
                ButtonSegment(
                  value: PaymentType.cash,
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(l10n.paymentCash),
                ),
                ButtonSegment(
                  value: PaymentType.credit,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(l10n.paymentCredit),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 20),
            if (!isCredit) ...[
              TextField(
                controller: _received,
                textDirection: TextDirection.ltr,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${l10n.received} (${currency.symbol})',
                  border: const OutlineInputBorder(),
                  errorText: invalidReceived
                      ? l10n.errInvalidAmount
                      : (shortfall ? l10n.receivedLessThanTotal : null),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (change != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${l10n.change}: ${money(change)}',
                  style: textTheme.titleLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ] else ...[
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(_customer?.name ?? l10n.chooseCustomer),
                  subtitle: _customer?.phone == null ? null : Text(_customer!.phone!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _chooseCustomer,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _paidNow,
                textDirection: TextDirection.ltr,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${l10n.paidNow} (${currency.symbol})',
                  border: const OutlineInputBorder(),
                  errorText: invalidPaid ? l10n.errInvalidAmount : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (remainingDebt != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${l10n.remainingDebt}: ${money(remainingDebt)}',
                  style: textTheme.titleLarge?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: canConfirm ? _confirm : null,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(l10n.confirmSale),
            ),
          ],
        ),
      ),
    );
  }
}
