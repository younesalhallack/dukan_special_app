import 'digits.dart';

String _two(int value) => value.toString().padLeft(2, '0');

/// `2026-10-14`
String formatDate(DateTime date, {DigitStyle digits = DigitStyle.western}) {
  return Digits.localize(
    '${date.year}-${_two(date.month)}-${_two(date.day)}',
    digits,
  );
}

/// `14:05`
String formatTime(DateTime date, {DigitStyle digits = DigitStyle.western}) {
  return Digits.localize('${_two(date.hour)}:${_two(date.minute)}', digits);
}

/// `2026-10-14 14:05`
String formatDateTime(DateTime date, {DigitStyle digits = DigitStyle.western}) {
  return '${formatDate(date, digits: digits)} ${formatTime(date, digits: digits)}';
}
