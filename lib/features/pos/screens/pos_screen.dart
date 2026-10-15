import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/barcode_utils.dart';
import '../../../core/utils/digits.dart';
import '../../../core/utils/quantity.dart';
import '../../../data/models/product.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/dual_price_text.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../inventory/screens/barcode_scanner_screen.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/cart_provider.dart';
import '../widgets/cart_line_tile.dart';
import '../widgets/pos_summary_bar.dart';
import 'checkout_screen.dart';
import 'sales_history_screen.dart';

/// Point of sale: search or scan products, build the cart, check out.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  void _addProduct(Product product) {
    ref.read(cartProvider.notifier).addProduct(product);
    _clearSearch();
    _focus.requestFocus();
  }

  /// Enter pressed: a hardware scanner types the code and presses Enter.
  Future<void> _submit(String text) async {
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
    await scanBarcodesContinuously(context, (code) async {
      final product = await repo.findByBarcode(code);
      if (product == null) return l10n.scanNotFound(code);
      ref.read(cartProvider.notifier).addProduct(product);
      return l10n.scanAdded(product.name);
    });
  }

  Future<void> _confirmClear() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clearCart),
        content: Text(l10n.clearCartConfirm),
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
    if (confirmed == true) ref.read(cartProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cart = ref.watch(cartProvider);
    final totals = ref.watch(cartTotalsProvider);
    final settings = ref.watch(settingsProvider).value;
    final digits = settings?.digitStyle ?? DigitStyle.western;

    Widget body;
    if (_query.trim().isNotEmpty) {
      body = _SearchResults(query: _query, digits: digits, onPick: _addProduct);
    } else if (cart.lines.isEmpty || totals == null) {
      body = Center(child: Text(l10n.cartEmpty));
    } else {
      body = ListView.separated(
        itemCount: cart.lines.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => CartLineTile(
          line: cart.lines[index],
          priced: totals.lines[index],
          currency: totals.currency,
          digits: digits,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pos),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: l10n.clearCart,
            onPressed: cart.lines.isEmpty ? null : _confirmClear,
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: l10n.salesHistory,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SalesHistoryScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _search,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.searchOrScan,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _clearSearch,
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
              onSubmitted: _submit,
            ),
          ),
          Expanded(child: body),
          if (totals != null && settings != null)
            PosSummaryBar(
              totals: totals,
              settings: settings,
              onCheckout: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CheckoutScreen()),
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.quantityShort(formatQuantity(product.quantity, digits: digits))),
              DualPriceText(
                amountMinor: product.salePrice,
                currency: product.saleCurrency,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          trailing: const Icon(Icons.add_circle_outline),
        );
      },
    );
  }
}
