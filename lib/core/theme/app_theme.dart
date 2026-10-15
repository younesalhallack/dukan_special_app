import 'package:flutter/material.dart';

/// App-wide Material theme.
///
/// The Cairo font files must be placed in `assets/fonts/` and declared in
/// pubspec.yaml. Until then Flutter silently uses its default font.
abstract final class AppTheme {
  static const String fontFamily = 'Cairo';

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.teal,
      fontFamily: fontFamily,
    );
  }
}
