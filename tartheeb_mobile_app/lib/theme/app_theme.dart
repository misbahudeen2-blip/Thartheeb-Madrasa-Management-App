import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Emerald
  static const Color emerald50 = Color(0xFFF6F9EE);
  static const Color emerald500 = Color(0xFF929F2B);
  static const Color emerald700 = Color(0xFF5F6D19);
  static const Color emerald900 = Color(0xFF2D350D);
  static const Color emerald950 = Color(0xFF1D2309);

  // Gold
  static const Color gold50 = Color(0xFFFFFBEB);
  static const Color gold500 = Color(0xFFE79C23);
  static const Color gold600 = Color(0xFFD97706);
  static const Color gold800 = Color(0xFF92400E);

  // Slate
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate900 = Color(0xFF0F172A);

  // Background and Gradients
  static const Color background = Color(0xFFF8FAFC);
  static const Color splashGradientStart = Color(0xFFFAFBF8);
  static const Color splashGradientMid = Color(0xFFEBF2D4);
  static const Color splashGradientEnd = Color(0xFFD3E3A4);

  // Brand
  static const Color brandTitle = Color(0xFF485217);

  // Status
  static const Color success = emerald500;
  static const Color warning = Colors.amber;
  static const Color error = Color(0xFFE11D48); // Rose
}

class AppTheme {
  // Static color shortcuts for easy screen access
  static const Color emerald50 = AppColors.emerald50;
  static const Color emerald500 = AppColors.emerald500;
  static const Color emerald700 = AppColors.emerald700;
  static const Color emerald900 = AppColors.emerald900;
  static const Color emerald950 = AppColors.emerald950;

  static const Color gold50 = AppColors.gold50;
  static const Color gold500 = AppColors.gold500;
  static const Color gold600 = AppColors.gold600;
  static const Color gold800 = AppColors.gold800;

  static const Color slate50 = AppColors.slate50;
  static const Color slate400 = AppColors.slate400;
  static const Color slate900 = AppColors.slate900;

  static const Color background = AppColors.background;
  static const Color splashGradientStart = AppColors.splashGradientStart;
  static const Color splashGradientMid = AppColors.splashGradientMid;
  static const Color splashGradientEnd = AppColors.splashGradientEnd;

  static const Color brandTitle = AppColors.brandTitle;

  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color error = AppColors.error;

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.emerald500,
        primary: AppColors.emerald500,
        secondary: AppColors.gold500,
        surface: AppColors.background,
        error: AppColors.error,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.cairo(color: AppColors.slate900),
        displayMedium: GoogleFonts.cairo(color: AppColors.slate900),
        displaySmall: GoogleFonts.cairo(color: AppColors.slate900),
        headlineLarge: GoogleFonts.cairo(color: AppColors.slate900),
        headlineMedium: GoogleFonts.cairo(color: AppColors.slate900),
        headlineSmall: GoogleFonts.cairo(color: AppColors.slate900),
        titleLarge: GoogleFonts.cairo(color: AppColors.slate900),
        titleMedium: GoogleFonts.cairo(color: AppColors.slate900),
        titleSmall: GoogleFonts.cairo(color: AppColors.slate900),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.slate400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.slate400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emerald500, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald500,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );

    return base;
  }

  static BoxDecoration get glassCardDecoration {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.8),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
