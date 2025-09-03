import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leadloq/features/leads/presentation/widgets/lead_sales_pitch_section.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';
import 'package:leadloq/features/leads/presentation/providers/sales_pitch_provider.dart';

void main() {
  group('LeadSalesPitchSection Tests', () {
    testWidgets('Sales pitch section shows correct UI', (WidgetTester tester) async {
      // Create a mock lead
      final mockLead = Lead(
        id: 'test-id',
        businessName: 'Test Business',
        phone: '(555) 123-4567',
        location: 'Test City',
        industry: 'test',
        status: LeadStatus.new_,
        hasWebsite: false,
        isCandidate: true,
        meetsRatingThreshold: true,
        hasRecentReviews: true,
        source: 'test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        timeline: [],
      );

      // Create mock sales pitches
      final mockPitches = [
        SalesPitch(
          id: 'pitch-1',
          name: 'Test Pitch 1',
          content: 'This is a test pitch for [Business Name] in [Location]',
          isDefault: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        SalesPitch(
          id: 'pitch-2',
          name: 'Test Pitch 2',
          content: 'Another test pitch for [Business Name]',
          isDefault: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // Build just the sales pitch section widget with ProviderScope
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesPitchesProvider.overrideWith((ref) => SalesPitchesNotifier()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: LeadSalesPitchSection(lead: mockLead),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify that the sales pitch header is visible
      expect(
        find.text('Sales Pitch'),
        findsOneWidget,
        reason: 'Sales pitch section header must be visible',
      );

      // Verify the expand/collapse icon is present  
      final expandIcon = find.byIcon(Icons.expand_more);
      final collapseIcon = find.byIcon(Icons.expand_less);
      expect(
        expandIcon.evaluate().isNotEmpty || collapseIcon.evaluate().isNotEmpty,
        true,
        reason: 'Sales pitch section should have expand/collapse icon',
      );
    });
  });
}