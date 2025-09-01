import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/core/theme/app_theme.dart';

void main() {
  group('Contrast Ratio Tests', () {
    test('Section headers have sufficient contrast on dark cards', () {
      // Test the old problematic combination
      const Color darkGrayOnElevated = AppTheme.darkGray;
      const Color elevatedSurface = AppTheme.elevatedSurface;
      
      final double badContrast = calculateContrastRatio(
        darkGrayOnElevated, 
        elevatedSurface
      );
      
      // Old contrast (darkGray on elevatedSurface): ${badContrast.toStringAsFixed(2)}:1
      
      // Test the new improved combination
      final Color whiteOpacity = Colors.white.withOpacity(0.9);
      
      final double goodContrast = calculateContrastRatio(
        whiteOpacity,
        elevatedSurface
      );
      
      // New contrast (white 0.9 on elevatedSurface): ${goodContrast.toStringAsFixed(2)}:1
      
      // WCAG AA requires 4.5:1 for normal text
      expect(goodContrast, greaterThanOrEqualTo(4.5),
        reason: 'Section headers must meet WCAG AA contrast requirements (4.5:1)');
    });
    
    test('Clickable links have sufficient contrast', () {
      const Color primaryGold = AppTheme.primaryGold;
      const Color elevatedSurface = AppTheme.elevatedSurface;
      
      final double linkContrast = calculateContrastRatio(
        primaryGold,
        elevatedSurface
      );
      
      // Link contrast (primaryGold on elevatedSurface): ${linkContrast.toStringAsFixed(2)}:1
      
      // Links should meet at least 3:1 for large text or 4.5:1 for normal text
      expect(linkContrast, greaterThanOrEqualTo(3.0),
        reason: 'Links must have minimum contrast ratio of 3:1');
    });
    
    test('Status indicators have sufficient contrast', () {
      // Test success green
      const Color successGreen = AppTheme.successGreen;
      const Color elevatedSurface = AppTheme.elevatedSurface;
      
      final double successContrast = calculateContrastRatio(
        successGreen,
        elevatedSurface
      );
      
      // Success indicator contrast: ${successContrast.toStringAsFixed(2)}:1
      
      // Test error red
      final Color errorRed = AppTheme.errorRed.withOpacity(0.8);
      
      final double errorContrast = calculateContrastRatio(
        errorRed,
        elevatedSurface
      );
      
      // Error indicator contrast: ${errorContrast.toStringAsFixed(2)}:1
      
      // Icons with text should meet 3:1 minimum
      expect(successContrast, greaterThanOrEqualTo(3.0),
        reason: 'Success indicators must have minimum contrast');
      expect(errorContrast, greaterThanOrEqualTo(3.0),
        reason: 'Error indicators must have minimum contrast');
    });
  });
}

// Calculate WCAG contrast ratio between two colors
double calculateContrastRatio(Color foreground, Color background) {
  // Calculate relative luminance for a color
  double getLuminance(Color color) {
    final List<double> rgb = [
      (color.r * 255.0).round() / 255.0,
      (color.g * 255.0).round() / 255.0,
      (color.b * 255.0).round() / 255.0,
    ];
    
    // Apply gamma correction
    for (int i = 0; i < rgb.length; i++) {
      if (rgb[i] <= 0.03928) {
        rgb[i] = rgb[i] / 12.92;
      } else {
        rgb[i] = math.pow((rgb[i] + 0.055) / 1.055, 2.4).toDouble();
      }
    }
    
    // Calculate relative luminance
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
  }
  
  final double l1 = getLuminance(foreground);
  final double l2 = getLuminance(background);
  
  // Ensure L1 is the lighter color
  final double lighter = l1 > l2 ? l1 : l2;
  final double darker = l1 > l2 ? l2 : l1;
  
  // Calculate contrast ratio
  return (lighter + 0.05) / (darker + 0.05);
}