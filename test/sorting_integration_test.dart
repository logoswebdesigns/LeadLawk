import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:leadloq/features/leads/presentation/pages/leads_list_page.dart';
import 'package:leadloq/features/leads/presentation/providers/paginated_leads_provider.dart';
import 'package:leadloq/features/leads/data/datasources/leads_remote_datasource.dart';
import 'package:leadloq/features/leads/data/models/paginated_response.dart';
import 'package:leadloq/features/leads/data/models/lead_model.dart';
import 'package:leadloq/features/leads/presentation/widgets/sort_bar.dart';
import 'package:leadloq/features/leads/presentation/widgets/sort_options_modal.dart';
import 'package:go_router/go_router.dart';

@GenerateMocks([LeadsRemoteDataSource])
import 'sorting_integration_test.mocks.dart';

void main() {
  group('Sorting Integration Tests', () {
    late MockLeadsRemoteDataSource mockDataSource;
    
    setUp(() {
      mockDataSource = MockLeadsRemoteDataSource();
    });
    
    LeadModel createTestLeadModel(String id, String name, {
      double? rating,
      int? reviewCount,
      DateTime? createdAt,
    }) {
      return LeadModel(
        id: id,
        businessName: name,
        phone: '555-0001',
        location: 'Test City',
        industry: 'Test Industry',
        source: 'google_maps',
        status: 'new',
        hasWebsite: false,
        isCandidate: true,
        meetsRatingThreshold: false,
        hasRecentReviews: false,
        rating: rating,
        reviewCount: reviewCount,
        createdAt: createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        timeline: [],
      );
    }
    
    Widget createTestWidget({required Widget child}) {
      return ProviderScope(
        overrides: [
          leadsRemoteDataSourceProvider.overrideWithValue(mockDataSource),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => child,
              ),
              GoRoute(
                path: '/leads/:id',
                builder: (context, state) => const Scaffold(
                  body: Center(child: Text('Lead Detail')),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    testWidgets('Sort bar displays and responds to sort changes', (WidgetTester tester) async {
      // Arrange - Set up mock response
      final mockResponse = PaginatedResponse<LeadModel>(
        items: [
          createTestLeadModel('1', 'Alpha Business', rating: 3.0),
          createTestLeadModel('2', 'Beta Business', rating: 5.0),
          createTestLeadModel('3', 'Charlie Business', rating: 4.0),
        ],
        total: 3,
        page: 1,
        perPage: 25,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      );
      
      when(mockDataSource.getLeadsPaginated(
        page: anyNamed('page'),
        perPage: anyNamed('perPage'),
        status: anyNamed('status'),
        search: anyNamed('search'),
        candidatesOnly: anyNamed('candidatesOnly'),
        sortBy: anyNamed('sortBy'),
        sortAscending: anyNamed('sortAscending'),
      )).thenAnswer((_) async => mockResponse);
      
      // Act - Build the widget
      await tester.pumpWidget(createTestWidget(child: const LeadsListPage()));
      await tester.pumpAndSettle();
      
      // Assert - Sort bar is visible
      expect(find.byType(SortBar), findsOneWidget);
      expect(find.text('Newest'), findsOneWidget); // Default sort
      
      // Act - Tap on sort button to open modal
      await tester.tap(find.text('Newest'));
      await tester.pumpAndSettle();
      
      // Assert - Sort modal appears
      expect(find.byType(SortOptionsModal), findsOneWidget);
      expect(find.text('Rating'), findsOneWidget);
      expect(find.text('Reviews'), findsOneWidget);
      expect(find.text('Alphabetical'), findsOneWidget);
    });
    
    testWidgets('Changing sort option triggers API call with correct parameters', (WidgetTester tester) async {
      // Arrange - Set up initial response
      final initialResponse = PaginatedResponse<LeadModel>(
        items: [
          createTestLeadModel('1', 'Business A', rating: 3.0),
          createTestLeadModel('2', 'Business B', rating: 5.0),
        ],
        total: 2,
        page: 1,
        perPage: 25,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      );
      
      // Set up response for rating sort
      final ratingResponse = PaginatedResponse<LeadModel>(
        items: [
          createTestLeadModel('2', 'Business B', rating: 5.0),
          createTestLeadModel('1', 'Business A', rating: 3.0),
        ],
        total: 2,
        page: 1,
        perPage: 25,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      );
      
      // Mock initial load
      when(mockDataSource.getLeadsPaginated(
        page: anyNamed('page'),
        perPage: anyNamed('perPage'),
        status: anyNamed('status'),
        search: anyNamed('search'),
        candidatesOnly: anyNamed('candidatesOnly'),
        sortBy: 'created_at',
        sortAscending: false,
      )).thenAnswer((_) async => initialResponse);
      
      // Mock rating sort
      when(mockDataSource.getLeadsPaginated(
        page: anyNamed('page'),
        perPage: anyNamed('perPage'),
        status: anyNamed('status'),
        search: anyNamed('search'),
        candidatesOnly: anyNamed('candidatesOnly'),
        sortBy: 'rating',
        sortAscending: false,
      )).thenAnswer((_) async => ratingResponse);
      
      // Act - Build widget
      await tester.pumpWidget(createTestWidget(child: const LeadsListPage()));
      await tester.pumpAndSettle();
      
      // Verify initial load
      verify(mockDataSource.getLeadsPaginated(
        page: 1,
        perPage: anyNamed('perPage'),
        status: anyNamed('status'),
        search: anyNamed('search'),
        candidatesOnly: anyNamed('candidatesOnly'),
        sortBy: 'created_at',
        sortAscending: false,
      )).called(1);
      
      // Act - Open sort modal
      await tester.tap(find.text('Newest'));
      await tester.pumpAndSettle();
      
      // Act - Select Rating sort
      await tester.tap(find.text('Rating'));
      await tester.pumpAndSettle();
      
      // Assert - Verify API was called with rating sort
      verify(mockDataSource.getLeadsPaginated(
        page: 1,
        perPage: anyNamed('perPage'),
        status: anyNamed('status'),
        search: anyNamed('search'),
        candidatesOnly: anyNamed('candidatesOnly'),
        sortBy: 'rating',
        sortAscending: false,
      )).called(1);
    });
    
    testWidgets('Toggling sort direction triggers API call', (WidgetTester tester) async {
      // Arrange
      final descendingResponse = PaginatedResponse<LeadModel>(
        items: [
          createTestLeadModel('1', 'Business Z'),
          createTestLeadModel('2', 'Business A'),
        ],
        total: 2,
        page: 1,
        perPage: 25,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      );
      
      final ascendingResponse = PaginatedResponse<LeadModel>(
        items: [
          createTestLeadModel('2', 'Business A'),
          createTestLeadModel('1', 'Business Z'),
        ],
        total: 2,
        page: 1,
        perPage: 25,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      );
      
      // Mock responses
      when(mockDataSource.getLeadsPaginated(
        page: anyNamed('page'),
        perPage: anyNamed('perPage'),
        status: anyNamed('status'),
        search: anyNamed('search'),
        candidatesOnly: anyNamed('candidatesOnly'),
        sortBy: anyNamed('sortBy'),
        sortAscending: false,
      )).thenAnswer((_) async => descendingResponse);
      
      when(mockDataSource.getLeadsPaginated(
        page: anyNamed('page'),
        perPage: anyNamed('perPage'),
        status: anyNamed('status'),
        search: anyNamed('search'),
        candidatesOnly: anyNamed('candidatesOnly'),
        sortBy: anyNamed('sortBy'),
        sortAscending: true,
      )).thenAnswer((_) async => ascendingResponse);
      
      // Act - Build widget
      await tester.pumpWidget(createTestWidget(child: const LeadsListPage()));
      await tester.pumpAndSettle();
      
      // Act - Open sort modal
      await tester.tap(find.text('Newest'));
      await tester.pumpAndSettle();
      
      // Find and tap the sort direction toggle
      final ascendingToggle = find.byWidgetPredicate((widget) => 
        widget is InkWell && 
        widget.child is Row &&
        (widget.child as Row).children.any((child) => 
          child is Text && (child.data?.contains('Ascending') ?? false)
        )
      );
      
      expect(ascendingToggle, findsOneWidget);
      await tester.tap(ascendingToggle);
      await tester.pumpAndSettle();
      
      // Close modal
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      
      // Verify ascending sort was called
      verify(mockDataSource.getLeadsPaginated(
        page: anyNamed('page'),
        perPage: anyNamed('perPage'),
        status: anyNamed('status'),
        search: anyNamed('search'),
        candidatesOnly: anyNamed('candidatesOnly'),
        sortBy: anyNamed('sortBy'),
        sortAscending: true,
      )).called(greaterThanOrEqualTo(1));
    });
  });
}