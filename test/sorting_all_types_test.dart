import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:leadloq/features/leads/presentation/providers/paginated_leads_provider.dart';
import 'package:leadloq/features/leads/presentation/providers/job_provider.dart' show leadsRemoteDataSourceProvider;
import 'package:leadloq/features/leads/data/datasources/leads_remote_datasource.dart';
import 'package:leadloq/features/leads/data/models/paginated_response.dart';
import 'package:leadloq/features/leads/data/models/lead_model.dart';

@GenerateMocks([LeadsRemoteDataSource])
import 'sorting_all_types_test.mocks.dart';

void main() {
  group('Comprehensive Sorting Tests', () {
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
    
    LeadModel createTestLeadModel(
      String id, 
      String name, {
      double? rating,
      int? reviewCount,
      int? pagespeedMobileScore,
      int? pagespeedDesktopScore,
      double? conversionScore,
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
        pagespeedMobileScore: pagespeedMobileScore,
        pagespeedDesktopScore: pagespeedDesktopScore,
        conversionScore: conversionScore,
        createdAt: createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        timeline: [],
      );
    }
    
    group('Created At Sorting', () {
      test('should sort by created_at descending (newest first)', () async {
        final now = DateTime.now();
        final mockResponse = PaginatedResponse<LeadModel>(
          items: [
            createTestLeadModel('1', 'Newest', createdAt: now),
            createTestLeadModel('2', 'Middle', createdAt: now.subtract(Duration(days: 1))),
            createTestLeadModel('3', 'Oldest', createdAt: now.subtract(Duration(days: 2))),
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
          sortBy: 'created_at',
          sortAscending: false,
        )).thenAnswer((_) async => mockResponse);
        
        final notifier = container.read(paginatedLeadsProvider.notifier);
        await notifier.updateFilters(sortBy: 'created_at', sortAscending: false);
        final state = container.read(paginatedLeadsProvider);
        
        expect(state.leads.length, 3);
        expect(state.leads[0].businessName, 'Newest');
        expect(state.leads[1].businessName, 'Middle');
        expect(state.leads[2].businessName, 'Oldest');
      });
      
      test('should sort by created_at ascending (oldest first)', () async {
        final now = DateTime.now();
        final mockResponse = PaginatedResponse<LeadModel>(
          items: [
            createTestLeadModel('3', 'Oldest', createdAt: now.subtract(Duration(days: 2))),
            createTestLeadModel('2', 'Middle', createdAt: now.subtract(Duration(days: 1))),
            createTestLeadModel('1', 'Newest', createdAt: now),
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
          sortBy: 'created_at',
          sortAscending: true,
        )).thenAnswer((_) async => mockResponse);
        
        final notifier = container.read(paginatedLeadsProvider.notifier);
        await notifier.updateFilters(sortBy: 'created_at', sortAscending: true);
        final state = container.read(paginatedLeadsProvider);
        
        expect(state.leads.length, 3);
        expect(state.leads[0].businessName, 'Oldest');
        expect(state.leads[1].businessName, 'Middle');
        expect(state.leads[2].businessName, 'Newest');
      });
    });
    
    group('Business Name Sorting', () {
      test('should sort by business_name ascending (A-Z)', () async {
        final mockResponse = PaginatedResponse<LeadModel>(
          items: [
            createTestLeadModel('1', 'Alpha Business'),
            createTestLeadModel('2', 'Beta Business'),
            createTestLeadModel('3', 'Charlie Business'),
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
          sortBy: 'business_name',
          sortAscending: true,
        )).thenAnswer((_) async => mockResponse);
        
        final notifier = container.read(paginatedLeadsProvider.notifier);
        await notifier.updateFilters(sortBy: 'business_name', sortAscending: true);
        final state = container.read(paginatedLeadsProvider);
        
        expect(state.leads.length, 3);
        expect(state.leads[0].businessName, 'Alpha Business');
        expect(state.leads[1].businessName, 'Beta Business');
        expect(state.leads[2].businessName, 'Charlie Business');
      });
      
      test('should sort by business_name descending (Z-A)', () async {
        final mockResponse = PaginatedResponse<LeadModel>(
          items: [
            createTestLeadModel('3', 'Charlie Business'),
            createTestLeadModel('2', 'Beta Business'),
            createTestLeadModel('1', 'Alpha Business'),
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
          sortBy: 'business_name',
          sortAscending: false,
        )).thenAnswer((_) async => mockResponse);
        
        final notifier = container.read(paginatedLeadsProvider.notifier);
        await notifier.updateFilters(sortBy: 'business_name', sortAscending: false);
        final state = container.read(paginatedLeadsProvider);
        
        expect(state.leads.length, 3);
        expect(state.leads[0].businessName, 'Charlie Business');
        expect(state.leads[1].businessName, 'Beta Business');
        expect(state.leads[2].businessName, 'Alpha Business');
      });
    });
    
    group('Rating Sorting (with null handling)', () {
      test('should sort by rating descending (highest first, nulls last)', () async {
        final mockResponse = PaginatedResponse<LeadModel>(
          items: [
            createTestLeadModel('1', '5 Star Business', rating: 5.0),
            createTestLeadModel('2', '4 Star Business', rating: 4.0),
            createTestLeadModel('3', '3 Star Business', rating: 3.0),
            createTestLeadModel('4', 'No Rating Business', rating: null),
            createTestLeadModel('5', 'Another No Rating', rating: null),
          ],
          total: 5,
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
          sortBy: 'rating',
          sortAscending: false,
        )).thenAnswer((_) async => mockResponse);
        
        final notifier = container.read(paginatedLeadsProvider.notifier);
        await notifier.updateFilters(sortBy: 'rating', sortAscending: false);
        final state = container.read(paginatedLeadsProvider);
        
        expect(state.leads.length, 5);
        expect(state.leads[0].rating, 5.0);
        expect(state.leads[1].rating, 4.0);
        expect(state.leads[2].rating, 3.0);
        expect(state.leads[3].rating, null);
        expect(state.leads[4].rating, null);
      });
      
      test('should sort by rating ascending (lowest first, nulls last)', () async {
        final mockResponse = PaginatedResponse<LeadModel>(
          items: [
            createTestLeadModel('3', '3 Star Business', rating: 3.0),
            createTestLeadModel('2', '4 Star Business', rating: 4.0),
            createTestLeadModel('1', '5 Star Business', rating: 5.0),
            createTestLeadModel('4', 'No Rating Business', rating: null),
            createTestLeadModel('5', 'Another No Rating', rating: null),
          ],
          total: 5,
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
          sortBy: 'rating',
          sortAscending: true,
        )).thenAnswer((_) async => mockResponse);
        
        final notifier = container.read(paginatedLeadsProvider.notifier);
        await notifier.updateFilters(sortBy: 'rating', sortAscending: true);
        final state = container.read(paginatedLeadsProvider);
        
        expect(state.leads.length, 5);
        expect(state.leads[0].rating, 3.0);
        expect(state.leads[1].rating, 4.0);
        expect(state.leads[2].rating, 5.0);
        expect(state.leads[3].rating, null);
        expect(state.leads[4].rating, null);
      });
    });
    
    group('Review Count Sorting (with null handling)', () {
      test('should sort by review_count descending (most reviews first, nulls last)', () async {
        final mockResponse = PaginatedResponse<LeadModel>(
          items: [
            createTestLeadModel('1', 'Popular Business', reviewCount: 500),
            createTestLeadModel('2', 'Medium Business', reviewCount: 100),
            createTestLeadModel('3', 'Small Business', reviewCount: 10),
            createTestLeadModel('4', 'No Reviews', reviewCount: null),
          ],
          total: 4,
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
          sortBy: 'review_count',
          sortAscending: false,
        )).thenAnswer((_) async => mockResponse);
        
        final notifier = container.read(paginatedLeadsProvider.notifier);
        await notifier.updateFilters(sortBy: 'review_count', sortAscending: false);
        final state = container.read(paginatedLeadsProvider);
        
        expect(state.leads.length, 4);
        expect(state.leads[0].reviewCount, 500);
        expect(state.leads[1].reviewCount, 100);
        expect(state.leads[2].reviewCount, 10);
        expect(state.leads[3].reviewCount, null);
      });
      
      test('should sort by review_count ascending (least reviews first, nulls last)', () async {
        final mockResponse = PaginatedResponse<LeadModel>(
          items: [
            createTestLeadModel('3', 'Small Business', reviewCount: 10),
            createTestLeadModel('2', 'Medium Business', reviewCount: 100),
            createTestLeadModel('1', 'Popular Business', reviewCount: 500),
            createTestLeadModel('4', 'No Reviews', reviewCount: null),
          ],
          total: 4,
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
          sortBy: 'review_count',
          sortAscending: true,
        )).thenAnswer((_) async => mockResponse);
        
        final notifier = container.read(paginatedLeadsProvider.notifier);
        await notifier.updateFilters(sortBy: 'review_count', sortAscending: true);
        final state = container.read(paginatedLeadsProvider);
        
        expect(state.leads.length, 4);
        expect(state.leads[0].reviewCount, 10);
        expect(state.leads[1].reviewCount, 100);
        expect(state.leads[2].reviewCount, 500);
        expect(state.leads[3].reviewCount, null);
      });
    });
    
    group('PageSpeed Mobile Score Sorting (with null handling)', () {
      test('should sort by pagespeed_mobile_score descending (highest first, nulls last)', () async {
        final mockResponse = PaginatedResponse<LeadModel>(
          items: [
            createTestLeadModel('1', 'Fast Site', pagespeedMobileScore: 95),
            createTestLeadModel('2', 'Medium Site', pagespeedMobileScore: 65),
            createTestLeadModel('3', 'Slow Site', pagespeedMobileScore: 35),
            createTestLeadModel('4', 'Not Tested', pagespeedMobileScore: null),
            createTestLeadModel('5', 'No Website', pagespeedMobileScore: null),
          ],
          total: 5,
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
          sortBy: 'pagespeed_mobile_score',
          sortAscending: false,
        )).thenAnswer((_) async => mockResponse);
        
        final notifier = container.read(paginatedLeadsProvider.notifier);
        await notifier.updateFilters(sortBy: 'pagespeed_mobile_score', sortAscending: false);
        final state = container.read(paginatedLeadsProvider);
        
        expect(state.leads.length, 5);
        expect(state.leads[0].pagespeedMobileScore, 95);
        expect(state.leads[1].pagespeedMobileScore, 65);
        expect(state.leads[2].pagespeedMobileScore, 35);
        expect(state.leads[3].pagespeedMobileScore, null);
        expect(state.leads[4].pagespeedMobileScore, null);
      });
      
      test('should sort by pagespeed_mobile_score ascending (lowest first, nulls last)', () async {
        final mockResponse = PaginatedResponse<LeadModel>(
          items: [
            createTestLeadModel('3', 'Slow Site', pagespeedMobileScore: 35),
            createTestLeadModel('2', 'Medium Site', pagespeedMobileScore: 65),
            createTestLeadModel('1', 'Fast Site', pagespeedMobileScore: 95),
            createTestLeadModel('4', 'Not Tested', pagespeedMobileScore: null),
            createTestLeadModel('5', 'No Website', pagespeedMobileScore: null),
          ],
          total: 5,
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
          sortBy: 'pagespeed_mobile_score',
          sortAscending: true,
        )).thenAnswer((_) async => mockResponse);
        
        final notifier = container.read(paginatedLeadsProvider.notifier);
        await notifier.updateFilters(sortBy: 'pagespeed_mobile_score', sortAscending: true);
        final state = container.read(paginatedLeadsProvider);
        
        expect(state.leads.length, 5);
        expect(state.leads[0].pagespeedMobileScore, 35);
        expect(state.leads[1].pagespeedMobileScore, 65);
        expect(state.leads[2].pagespeedMobileScore, 95);
        expect(state.leads[3].pagespeedMobileScore, null);
        expect(state.leads[4].pagespeedMobileScore, null);
      });
    });
    
    group('Conversion Score Sorting (with null handling)', () {
      test('should sort by conversion_score descending (highest first, nulls last)', () async {
        final mockResponse = PaginatedResponse<LeadModel>(
          items: [
            createTestLeadModel('1', 'High Potential', conversionScore: 90.0),
            createTestLeadModel('2', 'Medium Potential', conversionScore: 60.0),
            createTestLeadModel('3', 'Low Potential', conversionScore: 30.0),
            createTestLeadModel('4', 'Not Scored', conversionScore: null),
          ],
          total: 4,
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
          sortBy: 'conversion_score',
          sortAscending: false,
        )).thenAnswer((_) async => mockResponse);
        
        final notifier = container.read(paginatedLeadsProvider.notifier);
        await notifier.updateFilters(sortBy: 'conversion_score', sortAscending: false);
        final state = container.read(paginatedLeadsProvider);
        
        expect(state.leads.length, 4);
        expect(state.leads[0].conversionScore, 90.0);
        expect(state.leads[1].conversionScore, 60.0);
        expect(state.leads[2].conversionScore, 30.0);
        expect(state.leads[3].conversionScore, null);
      });
      
      test('should sort by conversion_score ascending (lowest first, nulls last)', () async {
        final mockResponse = PaginatedResponse<LeadModel>(
          items: [
            createTestLeadModel('3', 'Low Potential', conversionScore: 30.0),
            createTestLeadModel('2', 'Medium Potential', conversionScore: 60.0),
            createTestLeadModel('1', 'High Potential', conversionScore: 90.0),
            createTestLeadModel('4', 'Not Scored', conversionScore: null),
          ],
          total: 4,
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
          sortBy: 'conversion_score',
          sortAscending: true,
        )).thenAnswer((_) async => mockResponse);
        
        final notifier = container.read(paginatedLeadsProvider.notifier);
        await notifier.updateFilters(sortBy: 'conversion_score', sortAscending: true);
        final state = container.read(paginatedLeadsProvider);
        
        expect(state.leads.length, 4);
        expect(state.leads[0].conversionScore, 30.0);
        expect(state.leads[1].conversionScore, 60.0);
        expect(state.leads[2].conversionScore, 90.0);
        expect(state.leads[3].conversionScore, null);
      });
    });
  });
}