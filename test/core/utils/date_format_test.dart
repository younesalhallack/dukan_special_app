import 'package:flutter_test/flutter_test.dart';

import 'package:dukan_special_app/core/utils/date_format.dart';
import 'package:dukan_special_app/core/utils/digits.dart';

void main() {
  final date = DateTime(2026, 3, 5, 9, 7);

  test('formats with zero padding', () {
    expect(formatDate(date), '2026-03-05');
    expect(formatTime(date), '09:07');
    expect(formatDateTime(date), '2026-03-05 09:07');
  });

  test('Arabic-Indic digits', () {
    expect(formatDate(date, digits: DigitStyle.arabicIndic), '٢٠٢٦-٠٣-٠٥');
    expect(formatTime(date, digits: DigitStyle.arabicIndic), '٠٩:٠٧');
  });
}
