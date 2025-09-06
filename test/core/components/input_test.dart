// Tests for AppInput component.
// Pattern: Widget Testing - input validation and behavior.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/core/components/inputs/app_input.dart';

void main() {
  group('AppInput Tests', () {
    testWidgets('renders with label', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppInput(
              label: 'Email',
            ),
          ),
        ),
      );
      
      expect(find.text('Email'), findsOneWidget);
    });
    
    testWidgets('shows hint text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppInput(
              hint: 'Enter your email',
            ),
          ),
        ),
      );
      
      expect(find.text('Enter your email'), findsOneWidget);
    });
    
    testWidgets('shows error text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppInput(
              errorText: 'Invalid email',
            ),
          ),
        ),
      );
      
      expect(find.text('Invalid email'), findsOneWidget);
    });
    
    testWidgets('calls onChanged when text changes', (WidgetTester tester) async {
      String? value;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppInput(
              onChanged: (v) => value = v,
            ),
          ),
        ),
      );
      
      await tester.enterText(find.byType(TextFormField), 'test');
      expect(value, equals('test'));
    });
    
    testWidgets('obscures text when obscureText is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppInput(
              obscureText: true,
            ),
          ),
        ),
      );
      
      final textField = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField),
          matching: find.byType(TextField),
        ),
      );
      expect(textField.obscureText, isTrue);
    });
    
    testWidgets('shows prefix and suffix icons', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppInput(
              prefixIcon: Icon(Icons.search),
              suffixIcon: Icon(Icons.clear),
            ),
          ),
        ),
      );
      
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });
  
  group('AppValidators Tests', () {
    test('required validator', () {
      final validator = AppValidators.required();
      
      expect(validator(null), equals('This field is required'));
      expect(validator(''), equals('This field is required'));
      expect(validator('value'), isNull);
    });
    
    test('email validator', () {
      final validator = AppValidators.email();
      
      expect(validator(''), isNull);
      expect(validator('invalid'), equals('Enter a valid email'));
      expect(validator('test@example.com'), isNull);
    });
    
    test('minLength validator', () {
      final validator = AppValidators.minLength(5);
      
      expect(validator(''), isNull);
      expect(validator('1234'), equals('Must be at least 5 characters'));
      expect(validator('12345'), isNull);
    });
    
    test('maxLength validator', () {
      final validator = AppValidators.maxLength(5);
      
      expect(validator(''), isNull);
      expect(validator('12345'), isNull);
      expect(validator('123456'), equals('Must be at most 5 characters'));
    });
    
    test('combine validators', () {
      final validator = AppValidators.combine([
        AppValidators.required(),
        AppValidators.email(),
      ]);
      
      expect(validator(''), equals('This field is required'));
      expect(validator('invalid'), equals('Enter a valid email'));
      expect(validator('test@example.com'), isNull);
    });
  });
}