import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leadloq/features/leads/presentation/providers/automation_form_provider.dart';
import 'package:leadloq/features/leads/presentation/pages/browser_automation_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BrowserAutomationPage Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Form displays all required fields', (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            automationFormProvider.overrideWith(
              (ref) => AutomationFormNotifier(prefs),
            ),
          ],
          child: const MaterialApp(
            home: BrowserAutomationPage(),
          ),
        ),
      );

      expect(find.text('Industry'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Result Limit'), findsOneWidget);
      expect(find.text('Advanced Settings'), findsOneWidget);
      expect(find.text('Run Scrape'), findsOneWidget);
    });

    testWidgets('Industry chips are selectable', (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            automationFormProvider.overrideWith(
              (ref) => AutomationFormNotifier(prefs),
            ),
          ],
          child: const MaterialApp(
            home: BrowserAutomationPage(),
          ),
        ),
      );

      await tester.tap(find.text('Painter'));
      await tester.pump();
      
      final painterChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Painter'),
      );
      expect(painterChip.selected, isTrue);
    });

    testWidgets('Custom industry field appears when Custom is selected', 
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            automationFormProvider.overrideWith(
              (ref) => AutomationFormNotifier(prefs),
            ),
          ],
          child: const MaterialApp(
            home: BrowserAutomationPage(),
          ),
        ),
      );

      expect(find.text('Custom Industry'), findsNothing);
      
      await tester.tap(find.text('Custom...'));
      await tester.pump();
      
      expect(find.text('Custom Industry'), findsOneWidget);
    });

    testWidgets('Advanced settings can be expanded', (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            automationFormProvider.overrideWith(
              (ref) => AutomationFormNotifier(prefs),
            ),
          ],
          child: const MaterialApp(
            home: BrowserAutomationPage(),
          ),
        ),
      );

      await tester.tap(find.text('Advanced Settings'));
      await tester.pumpAndSettle();
      
      expect(find.textContaining('Min Rating'), findsOneWidget);
      expect(find.textContaining('Min Reviews'), findsOneWidget);
      expect(find.textContaining('Recent Days'), findsOneWidget);
    });

    testWidgets('Form validation works', (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            automationFormProvider.overrideWith(
              (ref) => AutomationFormNotifier(prefs),
            ),
          ],
          child: const MaterialApp(
            home: BrowserAutomationPage(),
          ),
        ),
      );

      await tester.tap(find.text('Run Scrape'));
      await tester.pump();
      
      expect(find.text('Please enter a location'), findsOneWidget);
    });
  });
}
