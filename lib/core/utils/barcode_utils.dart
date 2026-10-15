import 'digits.dart';

/// Helpers for barcode text coming from the camera, a hardware scanner or
/// the keyboard.
abstract final class BarcodeUtils {
  static final RegExp _controlChars = RegExp(r'[\u0000-\u001F\u007F]');

  /// Cleans a raw scan: Arabic-Indic digits become Western digits, control
  /// characters (line breaks sent by hardware scanners, tabs, ...) are
  /// removed and the edges are trimmed. Returns null for blank input.
  static String? clean(String? raw) {
    if (raw == null) return null;
    final text = Digits.toWestern(raw).replaceAll(_controlChars, '').trim();
    return text.isEmpty ? null : text;
  }
}

/// Ignores repeated reads of the same code. While the same code keeps being
/// seen, the quiet period is extended, so a code held in front of the camera
/// is accepted once; it is accepted again after it was out of sight for
/// [window]. A different code is always accepted.
class ScanDebouncer {
  ScanDebouncer({
    this.window = const Duration(milliseconds: 1500),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration window;
  final DateTime Function() _clock;

  String? _lastCode;
  DateTime? _lastSeen;

  /// True when [code] should be processed.
  bool accept(String code) {
    final now = _clock();
    final lastSeen = _lastSeen;
    final isRepeat = code == _lastCode &&
        lastSeen != null &&
        now.difference(lastSeen) < window;
    _lastCode = code;
    _lastSeen = now;
    return !isRepeat;
  }

  void reset() {
    _lastCode = null;
    _lastSeen = null;
  }
}
