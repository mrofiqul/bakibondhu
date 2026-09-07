import 'package:flutter/material.dart';

/// App theme — "taka green" collection-first identity, Material 3, large and
/// glanceable for low-literacy users on cheap Android (spec §33, §NFR-8).
class AppTheme {
  /// Deep taka green (trust / money-back).
  static const Color seed = Color(0xFF17694A);

  /// Amount colour when the customer owes the shop (positive balance).
  static const Color owed = Color(0xFF9C3B2E);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F5F0),
      // A Bengali-capable font is provided by the OS on Android; bundle
      // Noto Sans Bengali (pubspec) before release and set fontFamily here.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52), // big touch target
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}
