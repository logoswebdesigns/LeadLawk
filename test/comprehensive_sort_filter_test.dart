import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:leadloq/features/leads/presentation/providers/paginated_leads_provider.dart';
import 'package:leadloq/features/leads/data/datasources/leads_remote_datasource.dart';
import 'package:leadloq/features/leads/data/models/paginated_response.dart';
import 'package:leadloq/features/leads/data/models/lead_model.dart';

@GenerateMocks([LeadsRemoteDataSource])
import 'comprehensive_sort_filter_test.mocks.dart';

void main() {
  group('Comprehensive Sort and Filter Tests', () {
    late ProviderContainer container;
    late MockLeadsRemoteDataSource mockDataSource;
    
    setUp(() {
      mockDataSource = MockLeadsRemoteDataSource();
      container = ProviderContainer(
        overrides: [
          leadsRemoteDataSourceProvider.overrideWithValue(mockDataSource),
        ],
      );
    });
    
    tearDown(() {
      container.dispose();
    });
    
    LeadModel createTestLeadModel(String id, String name, {
      double? rating,
      int? reviewCount,
      String? status,
    }) {
      return LeadModel(
        id: id,
        businessName: name,
        phone: '555-0001',
        location: 'Test City',
        industry: 'Test Industry',
        source: 'google_maps',
        status: status ?? 'new',
        hasWebsite: false,
        isCandidate: true,
        meetsRatingThreshold: false,
        hasRecentReviews: false,
        rating: rating,
        reviewCount: reviewCount,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        timeline: [],
      );
    }
    
    test('should handle complex filter and sort combinations', () async {
      // Setup different responses for different filter/sort combinations
      final defaultResponse = PaginatedResponse<LeadModel>(
        items: [
          createTestLeadModel('1', 'Alpha Co', rating: 4.5, reviewCount: 100),
          createTestLeadModel('2', 'Beta Inc', rating: 3.5, reviewCount: 50),
          createTestLeadModel('3', 'Charlie LLC', rating: 5.0, reviewCount: 200),
        ],
        total: 3,
        page: 1,
        perPage: 25,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      );
      
      // Mock any call initially
      when(mockDataSource.getLeadsPaginated(
        page: anyNamed('page'),
        perPage: anyNamed('perPage'),
        status: anyNamed('status'),
        search: anyNamed('search'),
        candidatesOnly: anyNamed('candidatesOnly'),
        sortBy: anyNamed('sortBy'),
        sortAscending: anyNamed('sortAscending'),
      )).thenAnswer((_) async => defaultResponse);
      
      final notifier = container.read(paginatedLeadsProvider.notifier);
      
      // Test 1: Apply status filter
      print('\n=== TEST 1: Apply status filter ===');
      await notifier.updateFilters(status: 'called');
      var state = container.read(paginatedLeadsProvider);
      expect(state.filters.status, 'called');
      expect(state.filters.sortBy, 'created_at'); // Default sort preserved
      
      // Test 2: Add search while keeping status
      print('\n=== TEST 2: Add search filter ===');
      await notifier.updateFilters(
        status: 'called',
        search: 'test',
      );
      state = container.read(paginatedLeadsProvider);
      expect(state.filters.status, 'called');
      expect(state.filters.search, 'test');
      expect(state.filters.sortBy, 'created_at');
      
      // Test 3: Change sort while keeping filters
      print('\n=== TEST 3: Change sort (keep filters) ===');
      await notifier.updateFilters(
        status: 'called',
        search: 'test',
        sortBy: 'rating',
        sortAscending: false,
      );
      state = container.read(paginatedLeadsProvider);
      expect(state.filters.status, 'called');
      expect(state.filters.search, 'test');
      expect(state.filters.sortBy, 'rating');
      expect(state.filters.sortAscending, false);
      
      // Test 4: Toggle sort direction only
      print('\n=== TEST 4: Toggle sort direction ===');
      await notifier.updateFilters(
        status: 'called',
        search: 'test',
        sortBy: 'rating',
        sortAscending: true,
      );
      state = container.read(paginatedLeadsProvider);
      expect(state.filters.status, 'called');
      expect(state.filters.search, 'test');
      expect(state.filters.sortBy, 'rating');
      expect(state.filters.sortAscending, true);
      
      // Test 5: Clear search but keep other filters
      print('\n=== TEST 5: Clear search filter ===');
      await notifier.updateFilters(
        status: 'called',
        search: null, // Explicitly clear search
        sortBy: 'rating',
        sortAscending: true,
      );
      state = container.read(paginatedLeadsProvider);
      expect(state.filters.status, 'called');
      expect(state.filters.search, null);
      expect(state.filters.sortBy, 'rating');
      expect(state.filters.sortAscending, true);
      
      // Test 6: Clear all filters but keep sort
      print('\n=== TEST 6: Clear all filters (keep sort) ===');
      await notifier.updateFilters(
        status: null,
        search: null,
        candidatesOnly: null,
        sortBy: 'rating',
        sortAscending: true,
      );
      state = container.read(paginatedLeadsProvider);
      expect(state.filters.status, null);
      expect(state.filters.search, null);
      expect(state.filters.candidatesOnly, null);
      expect(state.filters.sortBy, 'rating');
      expect(state.filters.sortAscending, true);
      
      print('\n=== All tests passed! ===');
    });
    
    test('should make correct API calls for each sort option', () async {
      final mockResponse = PaginatedResponse<LeadModel>(
        items: [],
        total: 0,
        page: 1,
        perPage: 25,
        totalPages: 0,
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
      
      final notifier = container.read(paginatedLeadsProvider.notifier);
      
      // Test each sort option
      final sortOptions = [
        ('created_at', 'Newest'),
        ('rating', 'Rating'),
        ('review_count', 'Reviews'),
        ('business_name', 'Alphabetical'),
        ('pagespeed_mobile_score', 'PageSpeed'),
        ('conversion_score', 'Conversion'),
      ];
      
      for (final (sortBy, name) in sortOptions) {
        print('\n=== Testing sort by $name ($sortBy) ===');
        await notifier.updateFilters(sortBy: sortBy, sortAscending: false);
        
        // Verify API was called with correct sort
        verify(mockDataSource.getLeadsPaginated(
          page: 1,
          perPage: anyNamed('perPage'),
          status: anyNamed('status'),
          search: anyNamed('search'),
          candidatesOnly: anyNamed('candidatesOnly'),
          sortBy: sortBy,
          sortAscending: false,
        )).called(greaterThanOrEqualTo(1));
      }
    });
  });
}