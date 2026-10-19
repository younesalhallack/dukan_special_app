import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/utils/barcode_utils.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/digits.dart';
import '../../../core/utils/quantity.dart';
import '../../../data/models/product.dart';
import '../../../data/models/purchase_request.dart';
import '../../../data/models/sale_transaction.dart';
import '../../../data/models/supplier.dart';
import '../../../l10n/l10n.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../inventory/screens/barcode_scanner_screen.dart';
import '../../pos/providers/cart_provider.dart';
import '../../pos/widgets/pos_dialogs.dart';
import '../../settings/providers/settings_providers.dart';
import '../../suppliers/providers/suppliers_providers.dart';
import '../../suppliers/widgets/supplier_picker.dart';
import '../logic/purchase_calculator.dart';
import '../providers/purchases_providers.dart';
import '../widgets/purchase_dialogs.dart';
import 'purchase_detail_screen.dart';

double _roundQuantity(double value) => double.parse(value.toStringAsFixed(3));

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// A new purchase invoice: supplier, products with their costs, payment.
/// Saving adds the quantities to the stock and (optionally) updates costs.
class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _supplierInvoice = TextEditingController();
  final _rate = TextEditingController();
  final _paidNow = TextEditingController();
  final _note = TextEditingController();

  List<PurchaseDraftLine> _lines = const [];
  Currency _currency = Currency.usd;
  int _discount = 0;
  PaymentType _type = PaymentType.cash;
  Supplier? _supplier;
  DateTime _date = _today();
  bool _updateCosts = true;
  bool _saving = false;
  bool _done = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).value;
    if (settings != null && settings.isConfigured) {
      _rate.text = Money.formatRate(settings.rate).replaceAll(',', '');
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    _supplierInvoice.dispose();
    _rate.dispose();
    _paidNow.dispose();
    _note.dispose();
    super.dispose();
  }

  // --- lines ---------------------------------------------------------------

  void _addProduct(Product product) {
    setState(() {
      final index = _lines.indexWhere((line) => line.productId == product.id);
      if (index >= 0) {
        final updated = [..._lines];
        updated[index] = updated[index].copyWith(
          quantity: _roundQuantity(updated[index].quantity + 1),
        );
        _lines = updated;
      } else {
        _lines = [
          ..._lines,
          PurchaseDraftLine(
            productId: product.id,
            name: product.name,
            quantity: 1,
            enteredCost: product.costPrice,
            enteredCurrency: product.costCurrency,
            previousCost: product.costPrice,
            previousCurrency: product.costCurrency,
          ),
        ];
      }
      _search.clear();
      _query = '';
    });
    _focus.requestFocus();
  }

  void _changeLine(int productId, PurchaseDraftLine Function(PurchaseDraftLine) change) {
    setState(() {
      _lines = [
        for (final line in _lines)
          line.productId == productId ? change(line) : line,
      ];
    });
  }

  void _setQuantity(int productId, double quantity) {
    if (quantity <= 0) {
      _removeLine(productId);
      return;
    }
    _changeLine(productId, (line) => line.copyWith(quantity: _roundQuantity(quantity)));
  }

  void _removeLine(int productId) {
    setState(() {
      _lines = [
        for (final line in _lines)
          if (line.productId != productId) line,
      ];
    });
  }

  /// Enter pressed: a hardware scanner types the code and presses Enter.
  Future<void> _submitSearch(String text) async {
    final code = BarcodeUtils.clean(text);
    if (code == null) return;
    final product = await ref.read(productRepositoryProvider).findByBarcode(code);
    if (!mounted) return;
    if (product != null) _addProduct(product);
    _focus.requestFocus();
  }

  Future<void> _openCamera() async {
    final l10n = context.l10n;
    final repo = ref.read(productRepositoryProvider);
    await scanBarcodesContinuously(
      context,
      (code) async {
        final product = await repo.findByBarcode(code);
        if (product == null) return l10n.scanNotFound(code);
        if (mounted) _addProduct(product);
        return l10n.scanAdded(product.name);
      },
      hint: l10n.continuousScanHintPurchase,
    );
  }

  // --- header fields ---------------------------------------------------------

  Future<void> _chooseSupplier() async {
    final supplier = await pickSupplier(context);
    if (supplier != null && mounted) setState(() => _supplier = supplier);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _editDiscount(PurchaseTotals totals) async {
    final value = await promptDiscount(
      context,
      currency: totals.currency,
      max: totals.subtotal,
      current: totals.discount,
    );
    if (value != null) setState(() => _discount = value);
  }

  // --- leaving and saving --------------------------------------------------

  Future<bool> _confirmDiscard() async {
    final l10n = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.discardPurchase),
        content: Text(l10n.discardPurchaseConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _save(PurchaseTotals totals, int? paid) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final request = PurchaseRequest(
      currency: totals.currency,
      exchangeRate: totals.rate,
      lines: totals.lines,
      // The chosen day, at the current time of day (keeps the order of the day).
      purchaseDate: DateTime(_date.year, _date.month, _date.day, now.hour, now.minute, now.second),
      discountAmount: totals.discount,
      paymentType: _type,
      paidAmount: _type == PaymentType.credit ? paid : null,
      supplierId: _supplier?.id,
      supplierInvoiceNumber: _supplierInvoice.text,
      note: _note.text,
      updateCosts: _updateCosts,
    );

    setState(() => _saving = true);
    try {
      final id = await ref.read(purchaseRepositoryProvider).create(request);
      ref.refreshInventory();
      ref.refreshSuppliers();
      ref.refreshPurchases();
      if (!mounted) return;
      setState(() => _done = true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.purchaseSaved)));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => PurchaseDetailScreen(purchaseId: id)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    }
  }

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final digits = settings?.digitStyle ?? DigitStyle.western;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final rate = Money.parseDecimal(_rate.text);
    final rateValid = rate != null && rate > 0;
    final totals = rateValid
        ? PurchaseCalculator.calculate(
            lines: _lines,
            currency: _currency,
            rate: rate,
            discount: _discount,
          )
        : null;
    String money(int amount) => Money.format(amount, _currency, digits: digits);

    // Credit: the amount paid now and the debt that remains.
    final isCredit = _type == PaymentType.credit;
    final paidText = _paidNow.text.trim();
    final paid = paidText.isEmpty ? 0 : Money.parse(paidText, _currency);
    final invalidPaid = totals != null && (paid == null || paid > totals.total);
    final remaining = (totals != null && !invalidPaid) ? totals.total - paid! : null;

    final canSave = !_saving &&
        totals != null &&
        !totals.isEmpty &&
        (!isCredit || (_supplier != null && !invalidPaid));

    Widget content;
    if (_query.trim().isNotEmpty) {
      content = _SearchResults(query: _query, digits: digits, onPick: _addProduct);
    } else {
      content = ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(_supplier?.name ?? l10n.chooseSupplier),
                    subtitle: _supplier == null && !isCredit
                        ? Text(l10n.noSupplierSelected)
                        : null,
                    trailing: _supplier == null
                        ? const Icon(Icons.chevron_right)
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _supplier = null),
                          ),
                    onTap: _chooseSupplier,
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _supplierInvoice,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: l10n.supplierInvoiceNumber,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text('${l10n.purchaseDate}: ${formatDate(_date, digits: digits)}'),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: Text(l10n.invoiceCurrency)),
                      SegmentedButton<Currency>(
                        segments: [
                          ButtonSegment(value: Currency.usd, label: Text(Currency.usd.symbol)),
                          ButtonSegment(value: Currency.syp, label: Text(Currency.syp.symbol)),
                        ],
                        selected: {_currency},
                        onSelectionChanged: (s) => setState(() {
                          _currency = s.first;
                          _discount = 0;
                          _paidNow.clear();
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rate,
                    textDirection: TextDirection.ltr,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.purchaseRate,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      errorText: rateValid ? null : l10n.errInvalidAmount,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
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
                  if (isCredit) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _paidNow,
                      textDirection: TextDirection.ltr,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '${l10n.paidNow} (${_currency.symbol})',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        errorText: invalidPaid ? l10n.errInvalidAmount : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (remaining != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${l10n.remainingDebt}: ${money(remaining)}',
                        style: textTheme.titleMedium?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.updateCosts),
                    subtitle: Text(l10n.updateCostsHint),
                    value: _updateCosts,
                    onChanged: (v) => setState(() => _updateCosts = v),
                  ),
                  TextField(
                    controller: _note,
                    decoration: InputDecoration(
                      labelText: l10n.note,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(l10n.addItems)),
            ),
          if (totals != null)
            for (var i = 0; i < _lines.length; i++)
              _LineTile(
                line: _lines[i],
                priced: totals.lines[i],
                currency: _currency,
                rate: totals.rate,
                digits: digits,
                onQuantityDelta: (delta) =>
                    _setQuantity(_lines[i].productId, _lines[i].quantity + delta),
                onEditQuantity: () async {
                  final value = await promptQuantity(context, _lines[i].quantity);
                  if (value != null) _setQuantity(_lines[i].productId, value);
                },
                onEditCost: () async {
                  final value = await promptUnitCost(
                    context,
                    currency: _currency,
                    initial: totals.lines[i].unitCost,
                  );
                  if (value != null) {
                    _changeLine(
                      _lines[i].productId,
                      (line) => line.copyWith(
                        enteredCost: value,
                        enteredCurrency: _currency,
                      ),
                    );
                  }
                },
                onRemove: () => _removeLine(_lines[i].productId),
              ),
        ],
      );
    }

    final secondary = (totals != null && rateValid)
        ? Money.convert(totals.total, from: _currency, to: _currency.other, rate: totals.rate)
        : null;

    return PopScope(
      canPop: _lines.isEmpty || _done,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && mounted) {
          setState(() => _done = true);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.newPurchase)),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                controller: _search,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.searchOrScanProduct,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_query.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                        ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: l10n.scanBarcode,
                        onPressed: _openCamera,
                      ),
                    ],
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
                onSubmitted: _submitSearch,
              ),
            ),
            Expanded(child: content),
            Material(
              elevation: 8,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (totals != null && totals.discount > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.subtotal),
                            Text(money(totals.subtotal)),
                          ],
                        ),
                      InkWell(
                        onTap: (totals == null || totals.isEmpty)
                            ? null
                            : () => _editDiscount(totals),
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
                              Text(
                                (totals != null && totals.discount > 0)
                                    ? '- ${money(totals.discount)}'
                                    : '—',
                              ),
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
                            money(totals?.total ?? 0),
                            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (secondary != null && (settings?.showDualCurrency ?? true))
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            Money.format(secondary, _currency.other, digits: digits),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: canSave ? () => _save(totals!, paid) : null,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(l10n.savePurchase),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of the purchase: quantity, unit cost, line total and the hint
/// about how the cost changed compared with the product's previous cost.
class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.priced,
    required this.currency,
    required this.rate,
    required this.digits,
    required this.onQuantityDelta,
    required this.onEditQuantity,
    required this.onEditCost,
    required this.onRemove,
  });

  final PurchaseDraftLine line;
  final PurchaseLine priced;
  final Currency currency;
  final double rate;
  final DigitStyle digits;
  final ValueChanged<double> onQuantityDelta;
  final VoidCallback onEditQuantity;
  final VoidCallback onEditCost;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    String money(int amount) => Money.format(amount, currency, digits: digits);

    final change = PurchaseCalculator.costChangePercent(
      unitCost: priced.unitCost,
      currency: currency,
      rate: rate,
      previousCost: line.previousCost,
      previousCurrency: line.previousCurrency,
    );
    String? changeText;
    Color? changeColor;
    if (change != null && change.abs() >= 0.05) {
      final sign = change > 0 ? '+' : '';
      changeText = l10n.costChange(
        Digits.localize('$sign${change.toStringAsFixed(1)}%', digits),
      );
      changeColor = change > 0 ? scheme.error : Colors.green.shade700;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.name,
                  style: textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                visualDensity: VisualDensity.compact,
                tooltip: l10n.delete,
                onPressed: onRemove,
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                visualDensity: VisualDensity.compact,
                onPressed: () => onQuantityDelta(-1),
              ),
              InkWell(
                onTap: onEditQuantity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    formatQuantity(line.quantity, digits: digits),
                    style: textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                visualDensity: VisualDensity.compact,
                onPressed: () => onQuantityDelta(1),
              ),
              Expanded(
                child: InkWell(
                  onTap: onEditCost,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '× ${money(priced.unitCost)}  ✎',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              Text(
                money(priced.lineTotal),
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (line.previousCost > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  Text(
                    l10n.previousCostLabel(
                      Money.format(line.previousCost, line.previousCurrency, digits: digits),
                    ),
                    style: textTheme.bodySmall,
                  ),
                  if (changeText != null)
                    Text(
                      changeText,
                      style: textTheme.bodySmall?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.digits,
    required this.onPick,
  });

  final String query;
  final DigitStyle digits;
  final ValueChanged<Product> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(posSearchProvider(query));
    final products = async.value;
    if (products == null) {
      return async.hasError
          ? Center(child: Text('${async.error}'))
          : const Center(child: CircularProgressIndicator());
    }
    if (products.isEmpty) return Center(child: Text(l10n.noProducts));

    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = products[index];
        return ListTile(
          onTap: () => onPick(product),
          title: Text(product.name),
          subtitle: Text(
            '${l10n.quantityShort(formatQuantity(product.quantity, digits: digits))}'
            '  •  ${l10n.costPrice}: ${Money.format(product.costPrice, product.costCurrency, digits: digits)}',
          ),
          trailing: const Icon(Icons.add_circle_outline),
        );
      },
    );
  }
}
