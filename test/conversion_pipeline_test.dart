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
      final leads = createTestLeads();
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(leads: leads),
            ),
          ),
        ),
      );

      expect(find.byType(ConversionPipeline), findsOneWidget);
      expect(find.text('Conversion Pipeline'), findsOneWidget);
      expect(find.text('3 total leads'), findsOneWidget);
    });

    testWidgets('displays all pipeline stages', (WidgetTester tester) async {
      final leads = createTestLeads();
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(leads: leads),
            ),
          ),
        ),
      );

      // Check for stage labels
      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('VIEWED'), findsOneWidget);
      expect(find.text('CALLED'), findsOneWidget);
      expect(find.text('INTERESTED'), findsOneWidget);
      expect(find.text('CALLBACK'), findsOneWidget);
      expect(find.text('CONVERTED'), findsOneWidget);
      expect(find.text('NO CONVERT'), findsOneWidget);
      expect(find.text('DNC'), findsOneWidget);
    });

    testWidgets('shows correct lead counts per stage', (WidgetTester tester) async {
      final leads = createTestLeads();
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(leads: leads),
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

    testWidgets('displays stage icons', (WidgetTester tester) async {
      final leads = createTestLeads();
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(leads: leads),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.fiber_new), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.phone), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('horizontal scrolling works', (WidgetTester tester) async {
      final leads = createTestLeads();
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ConversionPipeline(leads: leads),
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