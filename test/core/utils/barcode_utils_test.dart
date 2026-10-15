import 'package:flutter_test/flutter_test.dart';

import 'package:dukan_special_app/core/utils/barcode_utils.dart';

void main() {
  group('BarcodeUtils.clean', () {
    test('trims spaces and line breaks sent by hardware scanners', () {
      expect(BarcodeUtils.clean('  6221234567890\n'), '6221234567890');
      expect(BarcodeUtils.clean('12\r\n'), '12');
    });

    test('converts Arabic-Indic digits', () {
      expect(BarcodeUtils.clean('٦٢٢١٢٣٤'), '6221234');
    });

    test('keeps letters, dashes and inner characters', () {
      expect(BarcodeUtils.clean('ABC-123'), 'ABC-123');
    });

    test('removes control characters', () {
      expect(BarcodeUtils.clean('AB\tC\u0000'), 'ABC');
    });

    test('blank input returns null', () {
      expect(BarcodeUtils.clean(null), isNull);
      expect(BarcodeUtils.clean('   '), isNull);
      expect(BarcodeUtils.clean('\n'), isNull);
    });
  });

  group('ScanDebouncer', () {
    late DateTime now;
    late ScanDebouncer debouncer;

    setUp(() {
      now = DateTime(2026, 10, 14, 12);
      debouncer = ScanDebouncer(
        window: const Duration(seconds: 1),
        clock: () => now,
      );
    });

    void advance(int milliseconds) {
      now = now.add(Duration(milliseconds: milliseconds));
    }

    test('accepts the first read and rejects an immediate repeat', () {
      expect(debouncer.accept('A'), isTrue);
      advance(300);
      expect(debouncer.accept('A'), isFalse);
    });

    test('keeps rejecting while the same code stays in view', () {
      expect(debouncer.accept('A'), isTrue);
      advance(500);
      expect(debouncer.accept('A'), isFalse);
      advance(900); // 900 ms after the last sighting, still inside the window
      expect(debouncer.accept('A'), isFalse);
    });

    test('accepts the same code again after it was out of sight', () {
      expect(debouncer.accept('A'), isTrue);
      advance(1100);
      expect(debouncer.accept('A'), isTrue);
    });

    test('a different code is always accepted', () {
      expect(debouncer.accept('A'), isTrue);
      expect(debouncer.accept('B'), isTrue);
      expect(debouncer.accept('A'), isTrue);
    });

    test('reset forgets the last code', () {
      expect(debouncer.accept('A'), isTrue);
      debouncer.reset();
      expect(debouncer.accept('A'), isTrue);
    });
  });
}
