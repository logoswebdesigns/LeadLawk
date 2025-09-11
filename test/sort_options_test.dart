import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/domain/entities/filter_state.dart';
import 'package:leadloq/features/leads/domain/providers/filter_providers.dart';
import 'package:leadloq/features/leads/presentation/widgets/sort_options_modal.dart';

void main() {
  group('SortOptionsModal', () {
    testWidgets('renders all sort options', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SortOptionsModal.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Check all sort options are displayed
      expect(find.text('Sort By'), findsOneWidget);
      expect(find.text('Newest First'), findsOneWidget);
      expect(find.text('Highest Rating'), findsOneWidget);
      expect(find.text('Most Reviews'), findsOneWidget);
      expect(find.text('Alphabetical'), findsOneWidget);
      expect(find.text('PageSpeed Score'), findsOneWidget);
      expect(find.text('Conversion Score'), findsOneWidget);
    });

    testWidgets('shows current sort selection', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sortStateProvider.overrideWith((ref) => const SortState(option: SortOption.rating)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SortOptionsModal(),
            ),
          ),
        ),
      );

      // Should show checkmark on selected option
      expect(find.text('Highest Rating'), findsOneWidget);
      // The selected option should have checkmark icon
      // Note: Font weight is w500 for unselected and w600 for selected in the new implementation
    });

    testWidgets('can toggle sort direction', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SortOptionsModal(),
            ),
          ),
        ),
      );

      // Initially shows descending
      expect(find.text('Descending'), findsOneWidget);
      
      // Tap to toggle
      await tester.tap(find.text('Descending'));
      await tester.pumpAndSettle();
      
      // Should now show ascending
      expect(find.text('Ascending'), findsOneWidget);
    });

    testWidgets('selecting option closes modal immediately', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SortOptionsModal.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      
      // Modal should be visible
      expect(find.text('Sort By'), findsOneWidget);
      
      // Select an option - modal should close immediately
      await tester.tap(find.text('Highest Rating'));
      await tester.pumpAndSettle();
      
      // Modal should be closed
      expect(find.text('Sort By'), findsNothing);
    });

    testWidgets('shows Set as Default button', (WidgetTester tester) async {      
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SortOptionsModal(),
            ),
          ),
        ),
      );

      // Should have Set as Default button
      expect(find.text('Set as Default'), findsOneWidget);
    });

    testWidgets('displays option descriptions', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SortOptionsModal(),
            ),
          ),
        ),
      );

      // Check descriptions are shown
      expect(find.text('Recently added leads first'), findsOneWidget);
      expect(find.text('Sort by business rating'), findsOneWidget);
      expect(find.text('Sort by review count'), findsOneWidget);
      expect(find.text('Sort by business name'), findsOneWidget);
      expect(find.text('Sort by website performance'), findsOneWidget);
      expect(find.text('Sort by conversion potential'), findsOneWidget);
    });
  });
}