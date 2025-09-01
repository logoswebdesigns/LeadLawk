import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/presentation/widgets/advanced_filter_bar.dart';
import 'package:leadloq/features/leads/presentation/pages/leads_list_page.dart';

void main() {
  group('AdvancedFilterBar', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AdvancedFilterBar(),
            ),
          ),
        ),
      );

      expect(find.byType(AdvancedFilterBar), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Sort by'), findsOneWidget);
    });

    testWidgets('can toggle advanced filters', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AdvancedFilterBar(),
            ),
          ),
        ),
      );

      // Initially advanced filters are hidden
      expect(find.text('Show Advanced Filters'), findsOneWidget);
      expect(find.text('Rating Range'), findsNothing);

      // Toggle to show advanced filters
      await tester.tap(find.text('Show Advanced Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Hide Advanced Filters'), findsOneWidget);
      expect(find.text('Rating Range'), findsOneWidget);
      expect(find.text('Review Count'), findsOneWidget);
      expect(find.text('PageSpeed Score'), findsOneWidget);
    });

    testWidgets('search field accepts input', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AdvancedFilterBar(),
            ),
          ),
        ),
      );

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'test search');
      await tester.pumpAndSettle();

      expect(find.text('test search'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('status filter chips are displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdvancedFilterBar(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Candidates Only'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('VIEWED'), findsOneWidget);
      expect(find.text('CALLED'), findsOneWidget);
    });

    testWidgets('quick filter chips work', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AdvancedFilterBar(),
            ),
          ),
        ),
      );

      final hasWebsiteChip = find.text('Has Website');
      expect(hasWebsiteChip, findsOneWidget);
      
      await tester.tap(hasWebsiteChip);
      await tester.pumpAndSettle();
      
      // Chip should be selected after tap
      final filterChip = tester.widget<FilterChip>(
        find.ancestor(of: hasWebsiteChip, matching: find.byType(FilterChip)).first
      );
      expect(filterChip.selected, isTrue);
    });
  });
}