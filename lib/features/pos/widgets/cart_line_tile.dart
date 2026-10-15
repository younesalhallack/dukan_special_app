import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../core/utils/digits.dart';
import '../../../core/utils/quantity.dart';
import '../../../data/models/checkout_request.dart';
import '../../../l10n/l10n.dart';
import '../logic/cart_calculator.dart';
import '../providers/cart_provider.dart';
import 'pos_dialogs.dart';

/// One cart line: name, quantity controls, unit price and line total.
class CartLineTile extends ConsumerWidget {
  const CartLineTile({
    super.key,
    required this.line,
    required this.priced,
    required this.currency,
    required this.digits,
  });

  final CartLine line;
  final CheckoutLine priced;
  final Currency currency;
  final DigitStyle digits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(cartProvider.notifier);
    final exceedsStock = line.quantity > line.stockQuantity;
    final errorColor = Theme.of(context).colorScheme.error;

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
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (exceedsStock)
                Tooltip(
                  message: l10n.exceedsStock,
                  child: Icon(Icons.warning_amber_rounded, size: 18, color: errorColor),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                visualDensity: VisualDensity.compact,
                tooltip: l10n.delete,
                onPressed: () => notifier.remove(line.productId),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    notifier.setQuantity(line.productId, line.quantity - 1),
              ),
              InkWell(
                onTap: () async {
                  final value = await promptQuantity(context, line.quantity);
                  if (value != null) notifier.setQuantity(line.productId, value);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    formatQuantity(line.quantity, digits: digits),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    notifier.setQuantity(line.productId, line.quantity + 1),
              ),
              Expanded(
                child: Text(
                  '× ${Money.format(priced.unitPrice, currency, digits: digits)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                Money.format(priced.lineTotal, currency, digits: digits),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
