import 'digits.dart';

/// Formats a stock quantity: no decimals for whole numbers, otherwise up to
/// three decimals without trailing zeros.
String formatQuantity(double quantity, {DigitStyle digits = DigitStyle.western}) {
  final String text;
  if (quantity == quantity.roundToDouble()) {
    text = quantity.round().toString();
  } else {
    text = quantity
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return Digits.localize(text, digits);
}
