import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color cream = Color(0xFFF5F5DC);
  static const Color navy = Color(0xFF000080);
  static const Color _textDark = Color(0xFF1C1C1E);
  static const Color _textMuted = Color(0xFF6B6B6B);
  static const Color _divider = Color(0xFFD4D4B8);

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    // Playfair Display for headlines (journal/logbook feel)
    // System sans-serif (Roboto / SF Pro) for body — no extra download needed
    final serifDisplay = GoogleFonts.playfairDisplay;

    return base.copyWith(
      scaffoldBackgroundColor: cream,
      colorScheme: const ColorScheme.light(
        primary: navy,
        onPrimary: Colors.white,
        secondary: navy,
        onSecondary: Colors.white,
        surface: cream,
        onSurface: _textDark,
        surfaceContainerHighest: Color(0xFFEDEDD4),
        outline: _divider,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cream,
        foregroundColor: navy,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: _divider,
        centerTitle: false,
        titleTextStyle: serifDisplay(
          color: navy,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      textTheme: TextTheme(
        // ── Serif: headlines & titles ────────────────────────────────────
        displayLarge: serifDisplay(
            fontSize: 57, fontWeight: FontWeight.w700, color: _textDark),
        displayMedium: serifDisplay(
            fontSize: 45, fontWeight: FontWeight.w700, color: _textDark),
        displaySmall: serifDisplay(
            fontSize: 36, fontWeight: FontWeight.w700, color: _textDark),
        headlineLarge: serifDisplay(
            fontSize: 32, fontWeight: FontWeight.w700, color: _textDark),
        headlineMedium: serifDisplay(
            fontSize: 28, fontWeight: FontWeight.w600, color: _textDark),
        headlineSmall: serifDisplay(
            fontSize: 24, fontWeight: FontWeight.w600, color: _textDark),
        titleLarge: serifDisplay(
            fontSize: 22, fontWeight: FontWeight.w600, color: _textDark),
        // ── Sans-serif: body & labels ────────────────────────────────────
        titleMedium: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500, color: _textDark),
        titleSmall: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: _textDark),
        bodyLarge:
            const TextStyle(fontSize: 16, height: 1.6, color: _textDark),
        bodyMedium:
            const TextStyle(fontSize: 14, height: 1.5, color: _textDark),
        bodySmall:
            const TextStyle(fontSize: 12, height: 1.4, color: _textMuted),
        labelLarge: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: navy),
        labelMedium: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: _textMuted),
        labelSmall: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w400, color: _textMuted),
      ),
      dividerTheme: const DividerThemeData(color: _divider, thickness: 1),
      cardTheme: const CardThemeData(
        color: Color(0xFFFAFAE8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: _divider),
        ),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: navy),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }
}
