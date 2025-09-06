import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leadloq/features/leads/presentation/widgets/lead_sales_pitch_section.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';
import 'package:leadloq/features/leads/presentation/providers/sales_pitch_provider.dart';
import 'package:leadloq/features/leads/domain/entities/filter_state.dart';
import 'package:leadloq/features/leads/domain/repositories/filter_repository.dart';
import 'package:leadloq/features/leads/domain/providers/filter_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dartz/dartz.dart';

@GenerateMocks([FilterRepository])
import 'lead_detail_page_test.mocks.dart';

void main() {
  group('LeadSalesPitchSection Tests', () {
    late MockFilterRepository mockFilterRepository;
    
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      
      mockFilterRepository = MockFilterRepository();
      
      // Setup mock filter repository responses
      when(mockFilterRepository.getFilterState()).thenAnswer((_) async => const Right(LeadsFilterState()));
      when(mockFilterRepository.getSortState()).thenAnswer((_) async => const Right(SortState()));
      when(mockFilterRepository.getUIState()).thenAnswer((_) async => const Right(LeadsUIState()));
      when(mockFilterRepository.saveFilterState(any)).thenAnswer((_) async => const Right(null));
      when(mockFilterRepository.saveSortState(any)).thenAnswer((_) async => const Right(null));
      when(mockFilterRepository.saveUIState(any)).thenAnswer((_) async => const Right(null));
    });
    
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
        timeline: const [],
      );

      // Sales pitches will be automatically initialized by the provider

      // Build just the sales pitch section widget with ProviderScope
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesPitchesProvider.overrideWith((ref) => SalesPitchesNotifier()),
            sharedPreferencesFutureProvider.overrideWith((ref) async => await SharedPreferences.getInstance()),
            filterRepositoryProvider.overrideWith((ref) async => mockFilterRepository),
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