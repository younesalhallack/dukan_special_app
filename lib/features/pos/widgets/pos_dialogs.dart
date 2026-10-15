import 'package:flutter/material.dart';

import '../../../core/currency/currency.dart';
import '../../../core/currency/money.dart';
import '../../../core/utils/quantity.dart';
import '../../../l10n/l10n.dart';

/// Asks for a quantity greater than zero (decimals allowed).
Future<double?> promptQuantity(BuildContext context, double initial) {
  return showDialog<double>(
    context: context,
    builder: (_) => _NumberDialog<double>(
      title: context.l10n.quantityEdit,
      label: context.l10n.quantityField,
      initialText: formatQuantity(initial),
      parse: (text) {
        final value = Money.parseDecimal(text);
        return (value == null || value <= 0) ? null : value;
      },
      emptyValue: null,
    ),
  );
}

/// Asks for a discount amount in [currency], between 0 and [max].
/// An empty field means "no discount" (returns 0).
Future<int?> promptDiscount(
  BuildContext context, {
  required Currency currency,
  required int max,
  required int current,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _NumberDialog<int>(
      title: context.l10n.setDiscount,
      label: '${context.l10n.discount} (${currency.symbol})',
      initialText: current == 0
          ? ''
          : (currency.decimals == 0
              ? '$current'
              : (current / currency.minorFactor).toStringAsFixed(currency.decimals)),
      parse: (text) {
        final minor = Money.parse(text, currency);
        return (minor == null || minor < 0 || minor > max) ? null : minor;
      },
      emptyValue: 0,
    ),
  );
}

/// A small dialog with one numeric field. [parse] returns null for invalid
/// text; an empty field returns [emptyValue] (or is invalid when it is null).
class _NumberDialog<T> extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.label,
    required this.initialText,
    required this.parse,
    required this.emptyValue,
  });

  final String title;
  final String label;
  final String initialText;
  final T? Function(String text) parse;
  final T? emptyValue;

  @override
  State<_NumberDialog<T>> createState() => _NumberDialogState<T>();
}

class _NumberDialogState<T> extends State<_NumberDialog<T>> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    final T? value = text.isEmpty ? widget.emptyValue : widget.parse(text);
    if (value == null) {
      setState(() => _error = context.l10n.errInvalidAmount);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textDirection: TextDirection.ltr,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: widget.label, errorText: _error),
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
