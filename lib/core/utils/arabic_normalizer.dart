import 'digits.dart';

/// Normalizes text so that searching ignores common Arabic spelling
/// variations. The result is stored in the `name_normalized` columns and is
/// also applied to the user's search text.
abstract final class ArabicNormalizer {
  // Harakat (U+064B-U+065F), superscript alef (U+0670) and tatweel (U+0640).
  static final RegExp _marks = RegExp('[\u064B-\u065F\u0670\u0640]');
  // Alef with madda / hamza above / hamza below / wasla.
  static final RegExp _alefs = RegExp('[\u0622\u0623\u0625\u0671]');
  static final RegExp _spaces = RegExp(r'\s+');

  static String normalize(String input) {
    var text = Digits.toWestern(input);
    text = text.replaceAll(_marks, '');
    text = text.replaceAll(_alefs, '\u0627'); // أ إ آ ٱ -> ا
    text = text.replaceAll('\u0649', '\u064A'); // ى -> ي
    text = text.replaceAll('\u0629', '\u0647'); // ة -> ه
    text = text.replaceAll('\u0624', '\u0648'); // ؤ -> و
    text = text.replaceAll('\u0626', '\u064A'); // ئ -> ي
    text = text.toLowerCase();
    return text.replaceAll(_spaces, ' ').trim();
  }

  /// Normalized words of [input]; empty for blank text.
  static List<String> tokens(String input) {
    final text = normalize(input);
    if (text.isEmpty) return const <String>[];
    return text.split(' ');
  }
}
