import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/money.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/utils/digits.dart';
import '../../../core/utils/quantity.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_movement.dart';
import '../../../l10n/l10n.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/inventory_providers.dart';

/// Add stock (purchase) or reduce / correct it. Every change is logged in
/// `stock_movements`. Pops `true` when the stock was changed.
class StockAdjustDialog extends ConsumerStatefulWidget {
  const StockAdjustDialog({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends ConsumerState<StockAdjustDialog> {
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  bool _add = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final quantity = Money.parseDecimal(_quantity.text);
    if (quantity == null || quantity <= 0) {
      setState(() => _error = l10n.errInvalidQuantity);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(productRepositoryProvider).adjustStock(
            productId: widget.product.id,
            delta: _add ? quantity : -quantity,
            reason: _add ? StockReasons.restock : StockReasons.adjustment,
            note: _note.text,
          );
      ref.refreshInventory();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final digits =
        ref.watch(settingsProvider).value?.digitStyle ?? DigitStyle.western;

    return AlertDialog(
      title: Text(l10n.adjustStock),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.product.name,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.currentQuantity(
              formatQuantity(widget.product.quantity, digits: digits),
            )),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(l10n.addStock)),
                ButtonSegment(value: false, label: Text(l10n.reduceStock)),
              ],
              selected: {_add},
              onSelectionChanged: (s) => setState(() => _add = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantity,
              autofocus: true,
              textDirection: TextDirection.ltr,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.quantityField,
                errorText: _error,
              ),
            ),
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
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
