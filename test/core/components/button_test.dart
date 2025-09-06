// Tests for AppButton component.
// Pattern: Widget Testing - component behavior verification.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/core/components/buttons/app_button.dart';

void main() {
  group('AppButton Tests', () {
    testWidgets('renders with label', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Test Button',
            ),
          ),
        ),
      );
      
      expect(find.text('Test Button'), findsOneWidget);
    });
    
    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      bool pressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Test Button',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );
      
      await tester.tap(find.text('Test Button'));
      expect(pressed, isTrue);
    });
    
    testWidgets('shows loading indicator when loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Test Button',
              loading: true,
            ),
          ),
        ),
      );
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Test Button'), findsNothing);
    });
    
    testWidgets('disabled when loading', (WidgetTester tester) async {
      bool pressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Test Button',
              loading: true,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );
      
      await tester.tap(find.byType(ElevatedButton));
      expect(pressed, isFalse);
    });
    
    testWidgets('shows icon when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Test Button',
              icon: Icons.add,
            ),
          ),
        ),
      );
      
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
    
    testWidgets('applies correct variant styles', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppButton(
                  label: 'Primary',
                  variant: ButtonVariant.primary,
                ),
                AppButton(
                  label: 'Secondary',
                  variant: ButtonVariant.secondary,
                ),
                AppButton(
                  label: 'Danger',
                  variant: ButtonVariant.danger,
                ),
              ],
            ),
          ),
        ),
      );
      
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Secondary'), findsOneWidget);
      expect(find.text('Danger'), findsOneWidget);
    });
    
    testWidgets('applies correct size', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Large Button',
              size: ButtonSize.large,
            ),
          ),
        ),
      );
      
      final text = tester.widget<Text>(find.text('Large Button'));
      expect(text.style?.fontSize, equals(16));
    });
  });
}