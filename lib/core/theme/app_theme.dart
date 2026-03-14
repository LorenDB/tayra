import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Core palette ──────────────────────────────────────────────────────
  static const Color background = Color(0xFF000000); // AMOLED black
  static const Color surface = Color(0xFF0A0A0A);
  static const Color surfaceContainer = Color(0xFF121212);
  static const Color surfaceContainerHigh = Color(0xFF1A1A1A);
  static const Color surfaceContainerHighest = Color(0xFF222222);
  static const Color primary = Color(0xFF0992F2); // Funkwhale purple-ish
  static const Color primaryLight = Color.fromARGB(255, 108, 213, 255);
  static const Color secondary = Color(0xFF00D4AA); // Teal accent
  static const Color error = Color(0xFFFF6B6B);
  static const Color onBackground = Color(0xFFFFFFFF);
  static const Color onBackgroundMuted = Color(0xFFB3B3B3);
  static const Color onBackgroundSubtle = Color(0xFF666666);
  static const Color divider = Color(0xFF1E1E1E);

  // ── Gradients ─────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
  );

  static LinearGradient coverGlow(Color dominantColor) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      dominantColor.withValues(alpha: 0.35),
      dominantColor.withValues(alpha: 0.08),
      background,
    ],
    stops: const [0.0, 0.5, 1.0],
  );

  static LinearGradient get subtleFade => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primary.withValues(alpha: 0.06), Colors.transparent],
  );

  // ── Theme data ────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: onBackground,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: onBackground,
        letterSpacing: -0.3,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onBackground,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onBackground,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onBackground,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: onBackgroundMuted,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: onBackground,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onBackgroundMuted,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: onBackgroundSubtle,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onBackground,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: onBackgroundMuted,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: onBackgroundSubtle,
        letterSpacing: 0.5,
      ),
    );

    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: primary,
        secondary: secondary,
        error: error,
        onSurface: onBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        surfaceContainerHighest: surfaceContainerHighest,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
        iconTheme: const IconThemeData(color: onBackground),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceContainer,
        selectedItemColor: primary,
        unselectedItemColor: onBackgroundSubtle,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: onBackgroundSubtle),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: onBackground, size: 24),
      dividerTheme: const DividerThemeData(color: divider, thickness: 0.5),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: surfaceContainerHighest,
        thumbColor: Colors.white,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        trackHeight: 3,
        overlayColor: primary.withValues(alpha: 0.15),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceContainerHighest,
        contentTextStyle: GoogleFonts.inter(color: onBackground, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
