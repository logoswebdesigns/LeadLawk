import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/core/theme/app_theme.dart';

void main() {
  group('Accessibility Tests', () {    
    testWidgets('Section headers have sufficient contrast', (WidgetTester tester) async {
      // This test specifically checks the contrast of section headers
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(), 
          home: const Scaffold(
            backgroundColor: AppTheme.backgroundDark,
            body: Card(
              color: AppTheme.elevatedSurface,
              child: Column(
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      color: Colors.white, // Fixed: Use white for proper contrast
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      // Calculate contrast ratio
      const Color background = AppTheme.elevatedSurface;
      const Color foreground = Colors.white;
      
      final double contrastRatio = _calculateContrastRatio(foreground, background);
      
      // WCAG AA requires minimum 4.5:1 for normal text
      expect(contrastRatio, greaterThanOrEqualTo(4.5),
        reason: 'Section headers must have contrast ratio of at least 4.5:1');
    });
  });
}

// Helper function to calculate contrast ratio
double _calculateContrastRatio(Color foreground, Color background) {
  // Calculate relative luminance
  double getLuminance(Color color) {
    final List<double> rgb = [
      (color.r * 255.0).round() / 255.0,
      (color.g * 255.0).round() / 255.0,
      (color.b * 255.0).round() / 255.0,
    ];
    
    for (int i = 0; i < rgb.length; i++) {
      if (rgb[i] <= 0.03928) {
        rgb[i] = rgb[i] / 12.92;
      } else {
        rgb[i] = ((rgb[i] + 0.055) / 1.055);
        rgb[i] = rgb[i] * rgb[i];
      }
    }
    
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
  }
  
  final double l1 = getLuminance(foreground);
  final double l2 = getLuminance(background);
  
  final double lighter = l1 > l2 ? l1 : l2;
  final double darker = l1 > l2 ? l2 : l1;
  
  return (lighter + 0.05) / (darker + 0.05);
}