// Application color system.
// Pattern: Material 3 Color System.
// Single Responsibility: Color definitions and schemes.

import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF63A4FF);
  static const Color primaryDark = Color(0xFF004BA0);
  
  // Secondary colors
  static const Color secondary = Color(0xFF00ACC1);
  static const Color secondaryLight = Color(0xFF5DDEF4);
  static const Color secondaryDark = Color(0xFF007C91);
  
  // Tertiary colors
  static const Color tertiary = Color(0xFF7B1FA2);
  static const Color tertiaryLight = Color(0xFFAE52D4);
  static const Color tertiaryDark = Color(0xFF4A0072);
  
  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Neutral colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);
  
  /// Get light color scheme
  static ColorScheme getLightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: white,
      primaryContainer: primaryLight,
      onPrimaryContainer: primaryDark,
      secondary: secondary,
      onSecondary: white,
      secondaryContainer: secondaryLight,
      onSecondaryContainer: secondaryDark,
      tertiary: tertiary,
      onTertiary: white,
      tertiaryContainer: tertiaryLight,
      onTertiaryContainer: tertiaryDark,
      error: error,
      onError: white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      background: grey50,
      onBackground: grey900,
      surface: white,
      onSurface: grey900,
      surfaceContainerHighest: grey100,
      onSurfaceVariant: grey700,
      outline: grey400,
      outlineVariant: grey300,
      shadow: black,
      scrim: black,
      inverseSurface: grey900,
      onInverseSurface: white,
      inversePrimary: primaryLight,
    );
  }
  
  /// Get dark color scheme
  static ColorScheme getDarkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: primaryLight,
      onPrimary: primaryDark,
      primaryContainer: primary,
      onPrimaryContainer: primaryLight,
      secondary: secondaryLight,
      onSecondary: secondaryDark,
      secondaryContainer: secondary,
      onSecondaryContainer: secondaryLight,
      tertiary: tertiaryLight,
      onTertiary: tertiaryDark,
      tertiaryContainer: tertiary,
      onTertiaryContainer: tertiaryLight,
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      background: grey900,
      onBackground: grey50,
      surface: grey800,
      onSurface: grey50,
      surfaceContainerHighest: grey700,
      onSurfaceVariant: grey300,
      outline: grey600,
      outlineVariant: grey700,
      shadow: black,
      scrim: black,
      inverseSurface: grey50,
      onInverseSurface: grey900,
      inversePrimary: primary,
    );
  }
}