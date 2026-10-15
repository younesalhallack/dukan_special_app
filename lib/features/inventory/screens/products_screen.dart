import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/digits.dart';
import '../../../core/utils/quantity.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/dual_price_text.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/inventory_providers.dart';
import '../widgets/stock_adjust_dialog.dart';
import 'barcode_scanner_screen.dart';
import 'product_form_screen.dart';

/// Product list with Arabic-aware search and category filter.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(productFilterProvider).query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    _search.text = code;
    ref.read(productFilterProvider.notifier).setQuery(code);
  }

  void _openForm([Product? product]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductFormScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final digits = settings?.digitStyle ?? DigitStyle.western;
    final defaultThreshold = (settings?.defaultLowStockThreshold ?? 5).toDouble();
    final filter = ref.watch(productFilterProvider);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final async = ref.watch(productsProvider);
    final products = async.value;

    Widget list;
    if (products == null) {
      list = async.hasError
          ? Center(child: Text('${async.error}'))
          : const Center(child: CircularProgressIndicator());
    } else if (products.isEmpty) {
      list = Center(child: Text(l10n.noProducts));
    } else {
      list = ListView.separated(
        itemCount: products.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _ProductTile(
          product: products[index],
          defaultThreshold: defaultThreshold,
          digits: digits,
          onTap: () => _openForm(products[index]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.products)),
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        tooltip: l10n.addProduct,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.searchProducts,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: l10n.scanBarcode,
                  onPressed: _scan,
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: ref.read(productFilterProvider.notifier).setQuery,
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(l10n.allCategories),
                    selected: filter.categoryId == null,
                    onSelected: (_) =>
                        ref.read(productFilterProvider.notifier).setCategory(null),
                  ),
                ),
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(category.name),
                      selected: filter.categoryId == category.id,
                      onSelected: (_) => ref
                          .read(productFilterProvider.notifier)
                          .setCategory(category.id),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: list),
        ],
      ),
    );
  }
}

enum _ProductAction { adjust, hide }

class _ProductTile extends ConsumerWidget {
  const _ProductTile({
    required this.product,
    required this.defaultThreshold,
    required this.digits,
    required this.onTap,
  });

  final Product product;
  final double defaultThreshold;
  final DigitStyle digits;
  final VoidCallback onTap;

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _ProductAction action,
  ) async {
    final l10n = context.l10n;
    switch (action) {
      case _ProductAction.adjust:
        await showDialog<bool>(
          context: context,
          builder: (_) => StockAdjustDialog(product: product),
        );
      case _ProductAction.hide:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.deactivate),
            content: Text(l10n.deactivateConfirm),
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
        await ref.read(productRepositoryProvider).setActive(product.id, false);
        ref.refreshInventory();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final low = product.isLowStock(defaultThreshold);
    final category = product.categoryName ?? l10n.uncategorized;

    return ListTile(
      onTap: onTap,
      title: Text(product.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  '$category  •  '
                  '${l10n.quantityShort(formatQuantity(product.quantity, digits: digits))}',
                ),
              ),
              if (low) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 2),
                Text(
                  l10n.lowStockBadge,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          DualPriceText(
            amountMinor: product.salePrice,
            currency: product.saleCurrency,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
      trailing: PopupMenuButton<_ProductAction>(
        onSelected: (action) => _onAction(context, ref, action),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _ProductAction.adjust,
            child: Text(l10n.adjustStock),
          ),
          PopupMenuItem(
            value: _ProductAction.hide,
            child: Text(l10n.deactivate),
          ),
        ],
      ),
    );
  }
}
