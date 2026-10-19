import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../core/currency/payment_math.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/utils/digits.dart';
import '../../../data/models/supplier.dart';
import '../../../data/models/supplier_balance.dart';
import '../../../l10n/l10n.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/suppliers_providers.dart';

/// Records a debt payment. Returns true when a payment was saved.
Future<bool?> showAddSupplierPaymentDialog(
  BuildContext context, {
  required Supplier supplier,
  required SupplierBalance balance,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _SupplierPaymentDialog(supplier: supplier, balance: balance),
  );
}

class _SupplierPaymentDialog extends ConsumerStatefulWidget {
  const _SupplierPaymentDialog({required this.supplier, required this.balance});

  final Supplier supplier;
  final SupplierBalance balance;

  @override
  ConsumerState<_SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
}

class _SupplierPaymentDialogState extends ConsumerState<_SupplierPaymentDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  static const DigitStyle _western = DigitStyle.western;
  late final List<Currency> _debtCurrencies;
  late Currency _applied;
  late Currency _pay;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final base = ref.read(settingsProvider).value?.baseCurrency ?? Currency.syp;
    _debtCurrencies = [
      for (final c in [base, base.other])
        if (widget.balance.of(c) > 0) c,
    ];
    _applied = _debtCurrencies.isEmpty ? base : _debtCurrencies.first;
    _pay = _applied;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  static String _plain(int minor, Currency currency) {
    return currency.decimals == 0
        ? '$minor'
        : (minor / currency.minorFactor).toStringAsFixed(currency.decimals);
  }

  Future<void> _save(double rate, int amount) async {
    final l10n = context.l10n;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await ref.read(supplierPaymentRepositoryProvider).addPayment(
            supplierId: widget.supplier.id,
            amount: amount,
            currency: _pay,
            appliedCurrency: _applied,
            rate: rate,
            note: _note.text,
          );
      ref.refreshSuppliers();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = errorMessage(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final DigitStyle? digits = settings?.digitStyle;
    final rate = settings?.rate;
    final balance = widget.balance.of(_applied);

    String money(int value, Currency c) =>
        Money.format(value, c, digits: digits ?? _western);

    // Live preview of what the payment does to the debt.
    int? amount;
    String? previewError;
    int? applied;
    final text = _amount.text.trim();
    if (text.isNotEmpty && rate != null) {
      amount = Money.parse(text, _pay);
      if (amount == null || amount <= 0) {
        previewError = l10n.errInvalidAmount;
      } else {
        try {
          applied = PaymentMath.resolveApplied(
            amount: amount,
            payCurrency: _pay,
            appliedCurrency: _applied,
            rate: rate,
            balance: balance,
          );
        } on AppException catch (e) {
          previewError = errorMessage(l10n, e);
        }
      }
    }

    return AlertDialog(
      title: Text('${l10n.recordPayment}: ${widget.supplier.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_debtCurrencies.length > 1) ...[
              Text(l10n.settleDebtIn),
              const SizedBox(height: 6),
              SegmentedButton<Currency>(
                segments: [
                  for (final c in _debtCurrencies)
                    ButtonSegment(value: c, label: Text(c.symbol)),
                ],
                selected: {_applied},
                onSelectionChanged: (s) => setState(() {
                  _applied = s.first;
                  _amount.clear();
                }),
              ),
              const SizedBox(height: 12),
            ],
            Text('${l10n.debtLabel}: ${money(balance, _applied)}'),
            const SizedBox(height: 12),
            Text(l10n.payInCurrency),
            const SizedBox(height: 6),
            SegmentedButton<Currency>(
              segments: [
                ButtonSegment(value: Currency.syp, label: Text(Currency.syp.symbol)),
                ButtonSegment(value: Currency.usd, label: Text(Currency.usd.symbol)),
              ],
              selected: {_pay},
              onSelectionChanged: (s) => setState(() {
                _pay = s.first;
                _amount.clear();
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              autofocus: true,
              textDirection: TextDirection.ltr,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.paymentAmount,
                errorText: previewError ?? _saveError,
                suffixIcon: TextButton(
                  onPressed: (rate == null || balance <= 0)
                      ? null
                      : () => setState(() {
                            _amount.text = _plain(
                              PaymentMath.settlementAmount(
                                balance: balance,
                                payCurrency: _pay,
                                appliedCurrency: _applied,
                                rate: rate,
                              ),
                              _pay,
                            );
                          }),
                  child: Text(l10n.settleAll),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (applied != null) ...[
              const SizedBox(height: 10),
              if (_pay != _applied && rate != null)
                Text(
                  '${l10n.exchangeRateUsed}: ${Money.formatRate(rate, digits: digits ?? _western)}',
                ),
              Text(l10n.appliedAmountLabel(money(applied, _applied))),
              Text(
                l10n.balanceAfter(money(balance - applied, _applied)),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.note),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: (_saving || applied == null || amount == null || rate == null)
              ? null
              : () => _save(rate, amount!),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
