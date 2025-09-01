import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/presentation/widgets/selection_action_bar.dart';
import 'package:leadloq/features/leads/presentation/widgets/sort_bar.dart';
import 'package:leadloq/features/leads/presentation/pages/leads_list_page.dart';

void main() {
  group('Bulk Selection', () {
    testWidgets('shows select button in sort bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SortBar(),
            ),
          ),
        ),
      );

      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('enters selection mode when select tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: const [
                  SortBar(),
                  SelectionActionBar(),
                ],
              ),
            ),
          ),
        ),
      );

      // Initially no bulk action bar visible
      expect(find.text('Cancel'), findsNothing);
      
      // Tap select button
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      
      // Bulk action bar should appear
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('0 selected'), findsOneWidget);
    });

    testWidgets('selection action bar shows delete button', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSelectionModeProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SelectionActionBar(),
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('0 selected'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.trash), findsOneWidget);
    });

    testWidgets('can cancel selection mode', (WidgetTester tester) async {
      late bool selectionMode = true;
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSelectionModeProvider.overrideWith((ref) {
              ref.listenSelf((_, next) => selectionMode = next);
              return true;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SelectionActionBar(),
            ),
          ),
        ),
      );

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      
      // Should exit selection mode
      expect(selectionMode, false);
    });

    testWidgets('shows selection count', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSelectionModeProvider.overrideWith((ref) => true),
            selectedLeadsProvider.overrideWith((ref) => {'1', '2', '3'}),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SelectionActionBar(),
            ),
          ),
        ),
      );

      expect(find.text('3 selected'), findsOneWidget);
    });
  });
}