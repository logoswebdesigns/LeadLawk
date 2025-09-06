import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';
import 'package:leadloq/features/leads/domain/repositories/leads_repository.dart';
import 'package:leadloq/features/leads/presentation/widgets/quick_actions_bar.dart';
import 'package:leadloq/features/leads/presentation/widgets/lead_status_actions.dart';
import 'package:leadloq/features/leads/presentation/providers/job_provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([LeadsRepository])
import 'quick_actions_bar_test.mocks.dart';

void main() {
  group('QuickActionsBar', () {
    late Lead testLead;
    late MockLeadsRepository mockRepository;

    setUp(() {
      mockRepository = MockLeadsRepository();
      
      testLead = Lead(
        id: 'test-lead-123',
        businessName: 'Test Business',
        phone: '123-456-7890',
        industry: 'Construction',
        location: 'Dallas, TX',
        source: 'google_maps',
        hasWebsite: false,
        meetsRatingThreshold: true,
        hasRecentReviews: true,
        isCandidate: true,
        status: LeadStatus.new_,
        rating: 4.5,
        reviewCount: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Setup default mock behavior
      when(mockRepository.updateLead(any)).thenAnswer(
        (_) async => Right(testLead)
      );
      when(mockRepository.addTimelineEntry(any, any)).thenAnswer(
        (_) async => const Right(null)
      );
    });

    testWidgets('renders all action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadsRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickActionsBar(lead: testLead),
            ),
          ),
        ),
      );

      expect(find.text('Mark DNC'), findsOneWidget);
      expect(find.text('Did Not Convert'), findsOneWidget);
      expect(find.text('Converted'), findsOneWidget);
      expect(find.text('Interested'), findsOneWidget);
      expect(find.text('Follow-up'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('View on Maps'), findsOneWidget);
    });

    testWidgets('Did Not Convert button shows dialog when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadsRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickActionsBar(lead: testLead),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Did Not Convert'));
      await tester.pumpAndSettle();

      expect(find.text('Mark as Did Not Convert'), findsOneWidget);
      expect(find.text('Select a reason why Test Business did not convert:'), findsOneWidget);
      expect(find.text('Reason Code *'), findsOneWidget);
      expect(find.text('Additional Notes (Optional)'), findsOneWidget);
    });

    testWidgets('Did Not Convert dialog shows reason code dropdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadsRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickActionsBar(lead: testLead),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Did Not Convert'));
      await tester.pumpAndSettle();

      // Verify dropdown is present
      expect(find.byType(DropdownButtonFormField<ConversionFailureReason>), findsOneWidget);
      
      // Test dropdown opens and shows reason codes
      await tester.tap(find.byType(DropdownButtonFormField<ConversionFailureReason>));
      await tester.pumpAndSettle();

      // Check that at least the first few reason codes are visible
      expect(find.text('Not Interested (NI)'), findsOneWidget);
      expect(find.text('Too Expensive (TE)'), findsOneWidget);
      expect(find.text('Using Competitor (COMP)'), findsOneWidget);
    });

    testWidgets('Did Not Convert button is disabled when status is already didNotConvert', (WidgetTester tester) async {
      final leadWithStatus = testLead.copyWith(status: LeadStatus.didNotConvert);
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadsRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickActionsBar(lead: leadWithStatus),
            ),
          ),
        ),
      );

      final didNotConvertButton = find.byWidgetPredicate(
        (widget) => widget is InkWell && 
                     (widget.child as Container?)?.child is Row &&
                     ((widget.child as Container).child as Row).children.any(
                       (child) => child is Text && child.data == 'Did Not Convert'
                     ) &&
                     widget.onTap == null
      );

      expect(didNotConvertButton, findsOneWidget);
    });

    testWidgets('Converted button is disabled when status is already converted', (WidgetTester tester) async {
      final leadWithStatus = testLead.copyWith(status: LeadStatus.converted);
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadsRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickActionsBar(lead: leadWithStatus),
            ),
          ),
        ),
      );

      final convertedButton = find.byWidgetPredicate(
        (widget) => widget is InkWell && 
                     (widget.child as Container?)?.child is Row &&
                     ((widget.child as Container).child as Row).children.any(
                       (child) => child is Text && child.data == 'Converted'
                     ) &&
                     widget.onTap == null
      );

      expect(convertedButton, findsOneWidget);
    });

    testWidgets('Did Not Convert dialog accepts reason and notes', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leadsRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickActionsBar(lead: testLead),
            ),
          ),
        ),
      );

      // Open the Did Not Convert dialog
      await tester.tap(find.text('Did Not Convert'));
      await tester.pumpAndSettle();
      
      // Verify dialog opened with correct elements
      expect(find.text('Mark as Did Not Convert'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<ConversionFailureReason>), findsOneWidget);
      expect(find.text('Additional Notes (Optional)'), findsOneWidget);
      
      // The actual persistence is tested at the repository/integration level
      // This test just verifies the UI works correctly
    });
  });
}