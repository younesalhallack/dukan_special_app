import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/digits.dart';
import '../../../core/utils/quantity.dart';
import '../../../l10n/l10n.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/inventory_providers.dart';
import '../widgets/stock_adjust_dialog.dart';

/// Products at or below their alert level, lowest stock first.
class LowStockScreen extends ConsumerWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value;
    final digits = settings?.digitStyle ?? DigitStyle.western;
    final defaultThreshold = (settings?.defaultLowStockThreshold ?? 5).toDouble();
    final async = ref.watch(lowStockProvider);
    final products = async.value;

    Widget body;
    if (products == null) {
      body = async.hasError
          ? Center(child: Text('${async.error}'))
          : const Center(child: CircularProgressIndicator());
    } else if (products.isEmpty) {
      body = Center(child: Text(l10n.noLowStock));
    } else {
      body = ListView.separated(
        itemCount: products.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final product = products[index];
          final threshold = product.lowStockThreshold ?? defaultThreshold;
          return ListTile(
            title: Text(product.name),
            subtitle: Text(
              '${l10n.quantityShort(formatQuantity(product.quantity, digits: digits))}'
              '  •  ${l10n.thresholdValue(formatQuantity(threshold, digits: digits))}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add_box_outlined),
              tooltip: l10n.addStock,
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => StockAdjustDialog(product: product),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lowStock)),
      body: body,
    );
  }
}
