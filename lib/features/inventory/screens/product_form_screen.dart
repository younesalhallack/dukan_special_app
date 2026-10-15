import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/utils/barcode_utils.dart';
import '../../../core/utils/digits.dart';
import '../../../core/utils/quantity.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/dual_price_text.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/inventory_providers.dart';
import '../widgets/name_dialog.dart';
import '../widgets/stock_adjust_dialog.dart';
import 'barcode_scanner_screen.dart';

/// Add or edit a product. The quantity of an existing product is changed
/// only through "Adjust stock", so every change leaves a trace.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _cost;
  late final TextEditingController _sale;
  late final TextEditingController _threshold;
  late final TextEditingController _quantity;
  late Currency _costCurrency;
  late Currency _saleCurrency;
  int? _categoryId;
  Product? _product;
  bool _saving = false;

  static String _plain(int minor, Currency currency) {
    return currency.decimals == 0
        ? '$minor'
        : (minor / currency.minorFactor).toStringAsFixed(currency.decimals);
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _product = p;
    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _cost = TextEditingController(
      text: (p == null || p.costPrice == 0) ? '' : _plain(p.costPrice, p.costCurrency),
    );
    _sale = TextEditingController(
      text: p == null ? '' : _plain(p.salePrice, p.saleCurrency),
    );
    _threshold = TextEditingController(
      text: p?.lowStockThreshold == null ? '' : formatQuantity(p!.lowStockThreshold!),
    );
    _quantity = TextEditingController();
    _costCurrency = p?.costCurrency ?? Currency.usd;
    _saleCurrency = p?.saleCurrency ?? Currency.usd;
    _categoryId = p?.categoryId;
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _cost.dispose();
    _sale.dispose();
    _threshold.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final l10n = context.l10n;
    final name = await showNameDialog(
      context,
      title: l10n.newCategory,
      label: l10n.categoryName,
    );
    if (name == null || !mounted) return;
    try {
      final id = await ref.read(categoryRepositoryProvider).create(name);
      ref.invalidate(categoriesProvider);
      if (mounted) setState(() => _categoryId = id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    }
  }

  Future<void> _adjustStock() async {
    final current = _product;
    if (current == null) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => StockAdjustDialog(product: current),
    );
    if (changed != true || !mounted) return;
    final fresh = await ref.read(productRepositoryProvider).getById(current.id);
    if (mounted) setState(() => _product = fresh);
  }

  Future<void> _scanBarcode() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    setState(() => _barcode.text = code);
    await _checkBarcode(code);
  }

  /// Warns right away when the barcode already belongs to another product.
  Future<void> _checkBarcode(String raw) async {
    final code = BarcodeUtils.clean(raw);
    if (code == null) return;
    final owner =
        await ref.read(productRepositoryProvider).findByBarcodeAnyStatus(code);
    if (owner == null || owner.id == _product?.id || !mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          owner.isActive
              ? l10n.barcodeUsedBy(owner.name)
              : l10n.barcodeUsedByHidden(owner.name),
        ),
        action: owner.isActive
            ? SnackBarAction(
                label: l10n.openProduct,
                onPressed: () {
                  if (!mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => ProductFormScreen(product: owner),
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final cost = _cost.text.trim().isEmpty
        ? 0
        : Money.parse(_cost.text, _costCurrency)!;
    final sale = Money.parse(_sale.text, _saleCurrency)!;
    final quantity = _quantity.text.trim().isEmpty
        ? 0.0
        : Money.parseDecimal(_quantity.text)!;
    final threshold = _threshold.text.trim().isEmpty
        ? null
        : Money.parseDecimal(_threshold.text);

    setState(() => _saving = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      final input = ProductInput(
        name: _name.text,
        categoryId: _categoryId,
        barcode: _barcode.text,
        costPrice: cost,
        costCurrency: _costCurrency,
        salePrice: sale,
        saleCurrency: _saleCurrency,
        lowStockThreshold: threshold,
        initialQuantity: quantity,
      );
      final existing = _product;
      if (existing == null) {
        await repo.create(input);
      } else {
        await repo.update(existing.id, input);
      }
      ref.refreshInventory();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    }
  }

  Widget _priceRow({
    required String label,
    required TextEditingController controller,
    required Currency currency,
    required ValueChanged<Currency> onCurrency,
    required String? Function(String?) validator,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            textDirection: TextDirection.ltr,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            validator: validator,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<Currency>(
          segments: [
            ButtonSegment(value: Currency.usd, label: Text(Currency.usd.symbol)),
            ButtonSegment(value: Currency.syp, label: Text(Currency.syp.symbol)),
          ],
          selected: {currency},
          onSelectionChanged: (s) => onCurrency(s.first),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final digits = settings?.digitStyle ?? DigitStyle.western;
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final product = _product;

    // Live preview of the sale price in both currencies and the margin.
    Widget? preview;
    final saleMinor = Money.parse(_sale.text, _saleCurrency);
    final costMinor = _cost.text.trim().isEmpty
        ? 0
        : Money.parse(_cost.text, _costCurrency);
    if (settings != null && settings.isConfigured && saleMinor != null) {
      String? margin;
      if (costMinor != null && costMinor > 0) {
        final saleSyp = Money.convert(
          saleMinor,
          from: _saleCurrency,
          to: Currency.syp,
          rate: settings.rate,
        );
        final costSyp = Money.convert(
          costMinor,
          from: _costCurrency,
          to: Currency.syp,
          rate: settings.rate,
        );
        if (costSyp > 0) {
          final percent = (saleSyp - costSyp) / costSyp * 100;
          margin = l10n.profitMargin(
            Digits.localize('${percent.toStringAsFixed(1)}%', digits),
          );
        }
      }
      preview = Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DualPriceText(
                amountMinor: saleMinor,
                currency: _saleCurrency,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (margin != null) ...[
                const SizedBox(height: 4),
                Text(margin),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(product == null ? l10n.addProduct : l10n.editProduct),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.productName,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.errInvalidName : null,
              ),
              const SizedBox(height: 16),
              Text(l10n.category, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: Text(l10n.uncategorized),
                    selected: _categoryId == null,
                    onSelected: (_) => setState(() => _categoryId = null),
                  ),
                  for (final category in categories)
                    ChoiceChip(
                      label: Text(category.name),
                      selected: _categoryId == category.id,
                      onSelected: (_) =>
                          setState(() => _categoryId = category.id),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(l10n.newCategory),
                    onPressed: _addCategory,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _barcode,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.barcode,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: l10n.scanBarcode,
                    onPressed: _scanBarcode,
                  ),
                ),
                // Hardware scanners type the code and press Enter.
                onFieldSubmitted: _checkBarcode,
              ),
              const SizedBox(height: 16),
              _priceRow(
                label: l10n.costPrice,
                controller: _cost,
                currency: _costCurrency,
                onCurrency: (c) => setState(() => _costCurrency = c),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return Money.parse(v, _costCurrency) == null
                      ? l10n.errInvalidPrice
                      : null;
                },
              ),
              const SizedBox(height: 16),
              _priceRow(
                label: l10n.salePrice,
                controller: _sale,
                currency: _saleCurrency,
                onCurrency: (c) => setState(() => _saleCurrency = c),
                validator: (v) => (v == null || Money.parse(v, _saleCurrency) == null)
                    ? l10n.errInvalidPrice
                    : null,
              ),
              if (preview != null) ...[
                const SizedBox(height: 8),
                preview,
              ],
              const SizedBox(height: 16),
              if (product == null)
                TextFormField(
                  controller: _quantity,
                  textDirection: TextDirection.ltr,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.initialQuantity,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return Money.parseDecimal(v) == null
                        ? l10n.errInvalidQuantity
                        : null;
                  },
                )
              else
                Card(
                  child: ListTile(
                    title: Text(
                      l10n.currentQuantity(
                        formatQuantity(product.quantity, digits: digits),
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: _adjustStock,
                      child: Text(l10n.adjustStock),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _threshold,
                textDirection: TextDirection.ltr,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.lowStockThresholdLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return Money.parseDecimal(v) == null
                      ? l10n.errInvalidQuantity
                      : null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
