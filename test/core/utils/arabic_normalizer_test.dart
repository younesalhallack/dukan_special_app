import 'package:flutter_test/flutter_test.dart';

import 'package:dukan_special_app/core/utils/arabic_normalizer.dart';
import 'package:dukan_special_app/core/utils/quantity.dart';
import 'package:dukan_special_app/core/utils/digits.dart';

void main() {
  group('ArabicNormalizer.normalize', () {
    test('unifies alef forms', () {
      expect(ArabicNormalizer.normalize('أحمد'), 'احمد');
      expect(ArabicNormalizer.normalize('إحمد'), 'احمد');
      expect(ArabicNormalizer.normalize('آحمد'), 'احمد');
    });

    test('removes diacritics and tatweel', () {
      expect(ArabicNormalizer.normalize('مُشْروب'), 'مشروب');
      expect(ArabicNormalizer.normalize('شــاي'), 'شاي');
    });

    test('unifies ta marbuta, alef maqsura and hamza carriers', () {
      expect(ArabicNormalizer.normalize('مدرسة'), 'مدرسه');
      expect(ArabicNormalizer.normalize('مستشفى'), 'مستشفي');
      expect(ArabicNormalizer.normalize('مؤسسة'), 'موسسه');
    });

    test('converts Arabic-Indic digits and lowercases Latin text', () {
      expect(ArabicNormalizer.normalize('علبة ٥٠٠ غ'), 'علبه 500 غ');
      expect(ArabicNormalizer.normalize('Pepsi 330ML'), 'pepsi 330ml');
    });

    test('collapses and trims whitespace', () {
      expect(ArabicNormalizer.normalize('  شاي   أخضر '), 'شاي اخضر');
      expect(ArabicNormalizer.normalize(''), '');
    });
  });

  group('ArabicNormalizer.tokens', () {
    test('splits into normalized words', () {
      expect(ArabicNormalizer.tokens('شاي  أخضر'), ['شاي', 'اخضر']);
      expect(ArabicNormalizer.tokens('   '), isEmpty);
    });
  });

  group('formatQuantity', () {
    test('whole numbers have no decimals', () {
      expect(formatQuantity(5), '5');
      expect(formatQuantity(0), '0');
    });

    test('fractions keep up to three decimals without trailing zeros', () {
      expect(formatQuantity(2.5), '2.5');
      expect(formatQuantity(0.125), '0.125');
      expect(formatQuantity(2.0004), '2');
    });

    test('Arabic-Indic digits', () {
      expect(formatQuantity(12.5, digits: DigitStyle.arabicIndic), '١٢٫٥');
    });
  });
}
