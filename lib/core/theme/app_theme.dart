import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Design Tokens ──
  static const deepBlack = Color(0xFF0A0A0A);
  static const accentYellow = Color(0xFFFFD600);
  static const accentCyan = Color(0xFF00E5FF);

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: deepBlack,
        colorScheme: const ColorScheme.dark(
          surface: deepBlack,
          primary: accentYellow,
          secondary: accentCyan,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: deepBlack,
          elevation: 0,
        ),
      );
}
