import 'package:flutter/material.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../l10n/l10n.dart';

/// Asks for a unit cost in [currency] (zero or more). Returns minor units.
Future<int?> promptUnitCost(
  BuildContext context, {
  required Currency currency,
  required int initial,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _CostDialog(currency: currency, initial: initial),
  );
}

class _CostDialog extends StatefulWidget {
  const _CostDialog({required this.currency, required this.initial});

  final Currency currency;
  final int initial;

  @override
  State<_CostDialog> createState() => _CostDialogState();
}

class _CostDialogState extends State<_CostDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial == 0
        ? ''
        : (widget.currency.decimals == 0
            ? '${widget.initial}'
            : (widget.initial / widget.currency.minorFactor)
                .toStringAsFixed(widget.currency.decimals)),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = Money.parse(_controller.text, widget.currency);
    if (value == null || value < 0) {
      setState(() => _error = context.l10n.errInvalidAmount);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.unitCostLabel),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textDirection: TextDirection.ltr,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: '${l10n.unitCostLabel} (${widget.currency.symbol})',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
