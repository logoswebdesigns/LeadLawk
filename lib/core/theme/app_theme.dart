import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Primary colors - Professional Dark theme
  static const Color primaryBlack = Color(0xFF1A1A1A);  // Dark charcoal
  static const Color primaryGold = Color(0xFFFFB700);   // Amber gold for better contrast
  static const Color accentGold = Color(0xFFFFC947);    // Lighter gold for hover states
  static const Color darkGold = Color(0xFFCC9200);      // Darker gold for pressed states
  
  // Background colors
  static const Color backgroundDark = Color(0xFF0D0D0D);    // Near black background
  static const Color surfaceDark = Color(0xFF1A1A1A);       // Slightly lighter for cards
  static const Color elevatedSurface = Color(0xFF262626);   // For elevated components
  
  // Badge and accent colors for better differentiation
  static const Color primaryBlue = Color(0xFF3B82F6);     // Blue for location/source
  static const Color primaryIndigo = Color(0xFF6366F1);   // Indigo for industry
  static const Color accentPurple = Color(0xFF8B5CF6);    // Purple for filters
  static const Color accentTeal = Color(0xFF14B8A6);      // Teal for website badges
  static const Color accentCyan = Color(0xFF06B6D4);      // Cyan for review badges
  
  // Utility colors (adjusted for dark theme)
  static const Color successGreen = Color(0xFF4ADE80);   // Brighter green for dark bg
  static const Color warningOrange = Color(0xFFFB923C);  // Adjusted orange
  static const Color errorRed = Color(0xFFF87171);       // Softer red
  static const Color darkGray = Color(0xFF1F2937);
  static const Color mediumGray = Color(0xFF9CA3AF);     // Lighter for dark bg
  static const Color lightGray = Color(0xFF374151);      // Darker for dark theme
  static const Color backgroundGray = backgroundDark;     // Map to dark background
  
  // Additional theme constants for filter bar
  static const Color surfaceColor = surfaceDark;
  static const Color borderColor = Color(0xFF404040);
  
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryGold,
        secondary: accentGold,
        surface: surfaceDark,
        error: errorRed,
        onPrimary: primaryBlack,
        onSecondary: primaryBlack,
        onSurface: Colors.white,
        onError: primaryBlack,
      ),
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: elevatedSurface),
        ),
        color: surfaceDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        selectedColor: primaryGold.withValues(alpha: 0.2),
        backgroundColor: elevatedSurface,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryIndigo, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed),
        ),
        labelStyle: const TextStyle(color: mediumGray),
        hintStyle: TextStyle(color: mediumGray.withValues(alpha: 0.7)),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
          color: darkGray,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -1,
          color: darkGray,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: darkGray,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: darkGray,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkGray,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: darkGray,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: darkGray,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: mediumGray,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: darkGray,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
      ),
    );
  }
  
  static BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 10,
    offset: const Offset(0, 2),
  );
  
  static BoxShadow elevatedShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.08),
    blurRadius: 20,
    offset: const Offset(0, 4),
  );
}