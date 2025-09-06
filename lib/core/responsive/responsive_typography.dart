// Responsive typography system.
// Pattern: Responsive Typography Scale.
// Single Responsibility: Screen-size adaptive text sizing.

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Responsive text that scales based on screen size
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final ResponsiveTextScale? scale;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  
  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.scale,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  
  @override
  Widget build(BuildContext context) {
    final effectiveScale = scale ?? ResponsiveTextScale.body;
    final effectiveStyle = effectiveScale.getStyle(context, style);
    
    return Text(
      text,
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Text scale definitions
class ResponsiveTextScale {
  final double mobileFactor;
  final double tabletFactor;
  final double desktopFactor;
  final double wideFactor;
  
  const ResponsiveTextScale({
    required this.mobileFactor,
    required this.tabletFactor,
    required this.desktopFactor,
    required this.wideFactor,
  });
  
  // Predefined scales
  static const display = ResponsiveTextScale(
    mobileFactor: 0.85,
    tabletFactor: 0.95,
    desktopFactor: 1.0,
    wideFactor: 1.1,
  );
  
  static const headline = ResponsiveTextScale(
    mobileFactor: 0.9,
    tabletFactor: 0.95,
    desktopFactor: 1.0,
    wideFactor: 1.05,
  );
  
  static const title = ResponsiveTextScale(
    mobileFactor: 0.95,
    tabletFactor: 1.0,
    desktopFactor: 1.0,
    wideFactor: 1.0,
  );
  
  static const body = ResponsiveTextScale(
    mobileFactor: 1.0,
    tabletFactor: 1.0,
    desktopFactor: 1.0,
    wideFactor: 1.0,
  );
  
  static const label = ResponsiveTextScale(
    mobileFactor: 1.0,
    tabletFactor: 1.0,
    desktopFactor: 1.0,
    wideFactor: 1.0,
  );
  
  double getFactor(BuildContext context) {
    if (AppBreakpoints.isWide(context)) return wideFactor;
    if (AppBreakpoints.isDesktop(context)) return desktopFactor;
    if (AppBreakpoints.isTablet(context)) return tabletFactor;
    return mobileFactor;
  }
  
  TextStyle? getStyle(BuildContext context, TextStyle? baseStyle) {
    final factor = getFactor(context);
    if (baseStyle == null) return null;
    
    return baseStyle.copyWith(
      fontSize: baseStyle.fontSize != null 
        ? baseStyle.fontSize! * factor 
        : null,
    );
  }
}

/// Responsive rich text
class ResponsiveRichText extends StatelessWidget {
  final TextSpan text;
  final ResponsiveTextScale? scale;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  
  const ResponsiveRichText({
    super.key,
    required this.text,
    this.scale,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });
  
  @override
  Widget build(BuildContext context) {
    final effectiveScale = scale ?? ResponsiveTextScale.body;
    final scaledText = _scaleTextSpan(context, text, effectiveScale);
    
    return RichText(
      text: scaledText,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
  
  TextSpan _scaleTextSpan(
    BuildContext context,
    TextSpan span,
    ResponsiveTextScale scale,
  ) {
    return TextSpan(
      text: span.text,
      style: scale.getStyle(context, span.style),
      children: span.children?.map((child) {
        if (child is TextSpan) {
          return _scaleTextSpan(context, child, scale);
        }
        return child;
      }).toList(),
      recognizer: span.recognizer,
    );
  }
}

/// Typography utilities
class ResponsiveTypography {
  /// Get responsive text theme
  static TextTheme getResponsiveTextTheme(BuildContext context) {
    final baseTheme = Theme.of(context).textTheme;
    final factor = _getGlobalFactor(context);
    
    return TextTheme(
      displayLarge: _scaleTextStyle(baseTheme.displayLarge, factor),
      displayMedium: _scaleTextStyle(baseTheme.displayMedium, factor),
      displaySmall: _scaleTextStyle(baseTheme.displaySmall, factor),
      headlineLarge: _scaleTextStyle(baseTheme.headlineLarge, factor),
      headlineMedium: _scaleTextStyle(baseTheme.headlineMedium, factor),
      headlineSmall: _scaleTextStyle(baseTheme.headlineSmall, factor),
      titleLarge: _scaleTextStyle(baseTheme.titleLarge, factor),
      titleMedium: _scaleTextStyle(baseTheme.titleMedium, factor),
      titleSmall: _scaleTextStyle(baseTheme.titleSmall, factor),
      bodyLarge: _scaleTextStyle(baseTheme.bodyLarge, factor),
      bodyMedium: _scaleTextStyle(baseTheme.bodyMedium, factor),
      bodySmall: _scaleTextStyle(baseTheme.bodySmall, factor),
      labelLarge: _scaleTextStyle(baseTheme.labelLarge, factor),
      labelMedium: _scaleTextStyle(baseTheme.labelMedium, factor),
      labelSmall: _scaleTextStyle(baseTheme.labelSmall, factor),
    );
  }
  
  static double _getGlobalFactor(BuildContext context) {
    if (AppBreakpoints.isWide(context)) return 1.05;
    if (AppBreakpoints.isDesktop(context)) return 1.0;
    if (AppBreakpoints.isTablet(context)) return 0.95;
    return 0.9;
  }
  
  static TextStyle? _scaleTextStyle(TextStyle? style, double factor) {
    if (style == null) return null;
    return style.copyWith(
      fontSize: style.fontSize != null ? style.fontSize! * factor : null,
    );
  }
  
  /// Calculate optimal reading width
  static double getOptimalReadingWidth(BuildContext context) {
    if (AppBreakpoints.isWide(context)) return 720;
    if (AppBreakpoints.isDesktop(context)) return 640;
    if (AppBreakpoints.isTablet(context)) return 480;
    return double.infinity;
  }
  
  /// Get line height multiplier
  static double getLineHeightMultiplier(BuildContext context) {
    if (AppBreakpoints.isWide(context)) return 1.6;
    if (AppBreakpoints.isDesktop(context)) return 1.5;
    if (AppBreakpoints.isTablet(context)) return 1.45;
    return 1.4;
  }
}