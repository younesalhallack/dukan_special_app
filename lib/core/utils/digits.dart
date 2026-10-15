/// How digits are displayed in the UI.
enum DigitStyle {
  western('western'),
  arabicIndic('arabic_indic');

  const DigitStyle(this.storageValue);

  /// Value saved in the `settings` table.
  final String storageValue;

  static DigitStyle fromStorage(String? value) {
    for (final style in values) {
      if (style.storageValue == value) return style;
    }
    return DigitStyle.western;
  }
}

/// Digit conversion helpers (Western 0-9 <-> Arabic-Indic ٠-٩).
abstract final class Digits {
  static const String _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  static const String _persian = '۰۱۲۳۴۵۶۷۸۹';

  /// Converts any Arabic-Indic / Persian digits and Arabic separators in
  /// [input] to their ASCII equivalents, so user input can be parsed.
  static String toWestern(String input) {
    final out = StringBuffer();
    for (final ch in input.split('')) {
      final arabic = _arabicIndic.indexOf(ch);
      final persian = _persian.indexOf(ch);
      if (arabic >= 0) {
        out.write(arabic);
      } else if (persian >= 0) {
        out.write(persian);
      } else if (ch == '٫') {
        out.write('.');
      } else if (ch == '٬' || ch == '،') {
        out.write(',');
      } else {
        out.write(ch);
      }
    }
    return out.toString();
  }

  /// Converts the ASCII digits (and `.` `,`) of [text] to the chosen [style].
  static String localize(String text, DigitStyle style) {
    if (style == DigitStyle.western) return text;
    final out = StringBuffer();
    for (final ch in text.split('')) {
      final code = ch.codeUnitAt(0);
      if (code >= 0x30 && code <= 0x39) {
        out.write(_arabicIndic[code - 0x30]);
      } else if (ch == '.') {
        out.write('٫');
      } else if (ch == ',') {
        out.write('٬');
      } else {
        out.write(ch);
      }
    }
    return out.toString();
  }
}
