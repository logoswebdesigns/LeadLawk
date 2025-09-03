import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/presentation/widgets/conversion_pipeline.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';

void main() {
  group('ConversionPipeline', () {
    List<Lead> createTestLeads() {
      return [
        Lead(
          id: '1',
          businessName: 'Test Business 1',
          phone: '555-0001',
          location: 'Test City',
          industry: 'Test Industry',
          source: 'google_maps',
          status: LeadStatus.new_,
          hasWebsite: false,
          isCandidate: true,
          meetsRatingThreshold: false,
          hasRecentReviews: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Lead(
          id: '2',
          businessName: 'Test Business 2',
          phone: '555-0002',
          location: 'Test City',
          industry: 'Test Industry',
          source: 'google_maps',
          status: LeadStatus.called,
          hasWebsite: true,
          isCandidate: false,
          meetsRatingThreshold: true,
          hasRecentReviews: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Lead(
          id: '3',
          businessName: 'Test Business 3',
          phone: '555-0003',
          location: 'Test City',
          industry: 'Test Industry',
          source: 'google_maps',
          status: LeadStatus.converted,
          hasWebsite: true,
          isCandidate: false,
          meetsRatingThreshold: true,
          hasRecentReviews: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
    }

    testWidgets('renders without errors', (WidgetTester tester) async {
      // ConversionPipeline now uses provider data instead of direct leads
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(),
            ),
          ),
        ),
      );

      expect(find.byType(ConversionPipeline), findsOneWidget);
      expect(find.text('Pipeline'), findsOneWidget);
      expect(find.text('3 leads'), findsOneWidget);
    });

    testWidgets('displays all pipeline stages', (WidgetTester tester) async {
      // ConversionPipeline now uses provider data instead of direct leads
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(),
            ),
          ),
        ),
      );

      // Check for stage labels (uppercase as rendered)
      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('VIEWED'), findsOneWidget);
      expect(find.text('CALLED'), findsOneWidget);
      expect(find.text('INTEREST'), findsOneWidget);
      expect(find.text('CALLBACK'), findsOneWidget);
      expect(find.text('WON'), findsOneWidget);
      expect(find.text('LOST'), findsOneWidget);
      expect(find.text('DNC'), findsOneWidget);
    });

    testWidgets('shows correct lead counts per stage', (WidgetTester tester) async {
      // ConversionPipeline now uses provider data instead of direct leads
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(),
            ),
          ),
        ),
      );

      // NEW stage should have 1 lead
      final newStageCount = find.text('1').first;
      expect(newStageCount, findsWidgets);

      // CONVERTED stage should have 1 lead
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('displays percentage for each stage', (WidgetTester tester) async {
      // ConversionPipeline now uses provider data instead of direct leads
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(),
            ),
          ),
        ),
      );

      // With 3 leads: 1 new, 1 called, 1 converted
      // Each non-empty stage should show 33%
      expect(find.text('33%'), findsNWidgets(3)); // 3 stages with 1 lead each
      // Empty stages should show 0%
      expect(find.text('0%'), findsNWidgets(5)); // 5 empty stages
    });

    testWidgets('horizontal scrolling works', (WidgetTester tester) async {
      // ConversionPipeline now uses provider data instead of direct leads
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(),
            ),
          ),
        ),
      );

      final listView = find.byType(ListView);
      expect(listView, findsOneWidget);
      
      // Verify horizontal scroll direction
      final ListView listViewWidget = tester.widget(listView);
      expect(listViewWidget.scrollDirection, Axis.horizontal);
    });
  });
}