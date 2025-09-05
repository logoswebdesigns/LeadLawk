import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/presentation/widgets/sort_bar.dart';
import 'package:leadloq/features/leads/presentation/pages/leads_list_page.dart';

void main() {
  group('Refresh Button Tests', () {
    testWidgets('Refresh button is visible in sort bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: const [
                  SortBar(),
                ],
              ),
            ),
          ),
        ),
      );

      // Check if Refresh text is present
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('Select and Sort buttons remain visible with Refresh button', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: const [
                  SortBar(),
                ],
              ),
            ),
          ),
        ),
      );

      // Check all buttons are present
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget); // Auto-refresh toggle (default off)
      // Sort button contains "Newest" text
      final sortButtonText = find.byWidgetPredicate((widget) {
        if (widget is Text && widget.data == 'Newest') {
          return true;
        }
        return false;
      });
      expect(sortButtonText, findsOneWidget);
    });
  });
}