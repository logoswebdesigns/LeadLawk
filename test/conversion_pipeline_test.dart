import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/presentation/widgets/conversion_pipeline.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';
import 'package:leadloq/features/leads/presentation/providers/lead_statistics_provider.dart';

void main() {
  group('ConversionPipeline', () {
    // Create mock statistics for testing
    LeadStatistics createMockStatistics() {
      return LeadStatistics(
        total: 10,
        byStatus: {
          LeadStatus.new_: 3,
          LeadStatus.viewed: 2,
          LeadStatus.called: 2,
          LeadStatus.interested: 2,
          LeadStatus.converted: 1,
        },
        conversionRate: 10.0,
      );
    }

    testWidgets('renders without crashing', (WidgetTester tester) async {
      final statistics = createMockStatistics();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadStatisticsProvider.overrideWith((ref) async => statistics),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(),
            ),
          ),
        ),
      );

      expect(find.byType(ConversionPipeline), findsOneWidget);
      expect(find.text('Pipeline'), findsOneWidget);
      
      // Wait for async data to load
      await tester.pump();
      
      // Should show total count
      expect(find.text('10'), findsAtLeastNWidgets(1));
    });

    testWidgets('displays all pipeline stages', (WidgetTester tester) async {
      final statistics = createMockStatistics();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadStatisticsProvider.overrideWith((ref) async => statistics),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(),
            ),
          ),
        ),
      );
      
      await tester.pump();

      // Check for stage labels
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Viewed'), findsOneWidget);
      expect(find.text('Contacted'), findsOneWidget);
      expect(find.text('Interested'), findsOneWidget);
      expect(find.text('Converted'), findsOneWidget);
    });

    testWidgets('displays correct counts for each stage', (WidgetTester tester) async {
      final statistics = createMockStatistics();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadStatisticsProvider.overrideWith((ref) async => statistics),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(),
            ),
          ),
        ),
      );
      
      await tester.pump();

      // Check for stage counts
      expect(find.text('3'), findsOneWidget); // New
      expect(find.text('2'), findsNWidgets(3)); // Viewed, Called, Interested all have 2
      expect(find.text('1'), findsOneWidget); // Converted
    });

    testWidgets('shows loading state initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadStatisticsProvider.overrideWith((ref) async {
              // Delay to test loading state
              await Future.delayed(Duration(milliseconds: 100));
              return createMockStatistics();
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(),
            ),
          ),
        ),
      );

      // Initially should show placeholder
      expect(find.text('...'), findsAtLeastNWidgets(1));
      
      // Pump and settle to complete the async operation
      await tester.pumpAndSettle();
    });

    testWidgets('displays conversion rate', (WidgetTester tester) async {
      final statistics = createMockStatistics();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadStatisticsProvider.overrideWith((ref) async => statistics),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(),
            ),
          ),
        ),
      );
      
      await tester.pump();

      // Should show conversion rate
      expect(find.text('10.0%'), findsOneWidget);
    });

    testWidgets('handles empty statistics gracefully', (WidgetTester tester) async {
      final emptyStatistics = LeadStatistics(
        total: 0,
        byStatus: {},
        conversionRate: 0.0,
      );
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadStatisticsProvider.overrideWith((ref) async => emptyStatistics),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(),
            ),
          ),
        ),
      );
      
      await tester.pump();

      // Should show 0 for total
      expect(find.text('0'), findsAtLeastNWidgets(1));
      // Should show 0.0% conversion rate
      expect(find.text('0.0%'), findsOneWidget);
    });

    testWidgets('pipeline bars scale correctly', (WidgetTester tester) async {
      final statistics = createMockStatistics();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadStatisticsProvider.overrideWith((ref) async => statistics),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(),
            ),
          ),
        ),
      );
      
      await tester.pump();
      
      // Check that AnimatedFractionallySizedBox exists for bars
      expect(find.byType(AnimatedFractionallySizedBox), findsNWidgets(5));
    });
  });
}