import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:leadloq/features/leads/presentation/providers/paginated_leads_provider.dart';
import 'package:leadloq/features/leads/presentation/providers/job_provider.dart' show leadsRemoteDataSourceProvider;
import 'package:leadloq/features/leads/data/datasources/leads_remote_datasource.dart';
import 'package:leadloq/features/leads/data/models/paginated_response.dart';
import 'package:leadloq/features/leads/data/models/lead_model.dart';
import 'package:leadloq/features/leads/domain/entities/filter_state.dart';
import 'package:leadloq/features/leads/domain/repositories/filter_repository.dart';
import 'package:leadloq/features/leads/domain/providers/filter_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartz/dartz.dart';

@GenerateMocks([LeadsRemoteDataSource, FilterRepository])
import 'pagination_sorting_test.mocks.dart';

void main() {
  group('Pagination and Sorting Tests', () {
    late ProviderContainer container;
    late MockLeadsRemoteDataSource mockDataSource;
    late MockFilterRepository mockFilterRepository;
    
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
    });
    
    setUp(() async {
      mockDataSource = MockLeadsRemoteDataSource();
      mockFilterRepository = MockFilterRepository();
      
      // Setup SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
      
      // Setup mock filter repository responses
      when(mockFilterRepository.getFilterState()).thenAnswer((_) async => const Right(LeadsFilterState()));
      when(mockFilterRepository.getSortState()).thenAnswer((_) async => const Right(SortState()));
      when(mockFilterRepository.getUIState()).thenAnswer((_) async => const Right(LeadsUIState()));
      when(mockFilterRepository.saveFilterState(any)).thenAnswer((_) async => const Right(null));
      when(mockFilterRepository.saveSortState(any)).thenAnswer((_) async => const Right(null));
      when(mockFilterRepository.saveUIState(any)).thenAnswer((_) async => const Right(null));
      
      container = ProviderContainer(
        overrides: [
          leadsRemoteDataSourceProvider.overrideWithValue(mockDataSource),
          sharedPreferencesFutureProvider.overrideWith((ref) async => await SharedPreferences.getInstance()),
          filterRepositoryProvider.overrideWith((ref) async => mockFilterRepository),
        ],
      );
    });
    
    tearDown(() {
      container.dispose();
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
    
    test('should load initial page with correct page size', () async {
      // Arrange
      final mockResponse = PaginatedResponse<LeadModel>(
        items: [
          createTestLeadModel('1', 'Business 1'),
          createTestLeadModel('2', 'Business 2'),
        ],
        total: 100,
        page: 1,
        perPage: 25,
        totalPages: 4,
        hasNext: true,
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
      
      // Act - wait for initialization
      final notifier = container.read(paginatedLeadsProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 100)); // Allow initialization
      await notifier.loadInitialLeads();
      final state = container.read(paginatedLeadsProvider);
      
      // Assert
      expect(state.leads.length, 2);
      expect(state.currentPage, 1);
      expect(state.totalPages, 4);
      expect(state.total, 100);
      expect(state.hasReachedEnd, false);
    });
    
    test('should update page size and reload', () async {
      // Arrange
      final mockResponse50 = PaginatedResponse<LeadModel>(
        items: List.generate(50, (i) => 
          createTestLeadModel('${i+1}', 'Business ${i+1}')
        ),
        total: 100,
        page: 1,
        perPage: 50,
        totalPages: 2,
        hasNext: true,
        hasPrev: false,
      );
      
      when(mockDataSource.getLeadsPaginated(
        page: anyNamed('page'),
        perPage: 50,
        status: anyNamed('status'),
        search: anyNamed('search'),
        candidatesOnly: anyNamed('candidatesOnly'),
        sortBy: anyNamed('sortBy'),
        sortAscending: anyNamed('sortAscending'),
      )).thenAnswer((_) async => mockResponse50);
      
      // Act - wait for initialization
      final notifier = container.read(paginatedLeadsProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 100)); // Allow initialization
      await notifier.updatePageSize(50);
      final state = container.read(paginatedLeadsProvider);
      
      // Assert
      expect(state.leads.length, 50);
      expect(state.totalPages, 2);
      
      // Verify the request was made with per_page=50
      verify(mockDataSource.getLeadsPaginated(
        page: 1,
        perPage: 50,
        status: anyNamed('status'),
        search: anyNamed('search'),
        candidatesOnly: anyNamed('candidatesOnly'),
        sortBy: anyNamed('sortBy'),
        sortAscending: anyNamed('sortAscending'),
      )).called(1);
    });
    
    test('should apply filters correctly', () async {
      // Arrange
      final mockResponse = PaginatedResponse<LeadModel>(
        items: [
          createTestLeadModel('1', 'Filtered Business'),
        ],
        total: 1,
        page: 1,
        perPage: 25,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      );
      
      when(mockDataSource.getLeadsPaginated(
        page: anyNamed('page'),
        perPage: anyNamed('perPage'),
        status: 'called',
        search: 'test',
        candidatesOnly: true,
        sortBy: anyNamed('sortBy'),
        sortAscending: anyNamed('sortAscending'),
      )).thenAnswer((_) async => mockResponse);
      
      // Act - wait for initialization
      final notifier = container.read(paginatedLeadsProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 100)); // Allow initialization
      await notifier.updateFilters(
        status: 'called',
        search: 'test',
        candidatesOnly: true,
      );
      
      // Assert
      verify(mockDataSource.getLeadsPaginated(
        page: 1,
        perPage: anyNamed('perPage'),
        status: 'called',
        search: 'test',
        candidatesOnly: true,
        sortBy: anyNamed('sortBy'),
        sortAscending: anyNamed('sortAscending'),
      )).called(1);
    });
    
    test('should apply sorting correctly', () async {
      // Arrange
      final mockResponse = PaginatedResponse<LeadModel>(
        items: [
          createTestLeadModel('1', 'A Business', rating: 5.0),
          createTestLeadModel('2', 'B Business', rating: 4.5),
        ],
        total: 2,
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
      
      // Act - wait for initialization  
      final notifier = container.read(paginatedLeadsProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 100)); // Allow initialization
      await notifier.updateFilters(
        sortBy: 'rating',
        sortAscending: false,
      );
      
      // Assert
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
    
    test('should preserve filters when changing sort', () async {
      // Arrange
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
      
      // Act - wait for initialization
      final notifier = container.read(paginatedLeadsProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 100)); // Allow initialization
      
      // First set filters
      await notifier.updateFilters(
        status: 'new',
        candidatesOnly: true,
      );
      
      // Then change sort
      await notifier.updateFilters(
        sortBy: 'review_count',
        sortAscending: true,
      );
      
      final state = container.read(paginatedLeadsProvider);
      
      // Assert - filters should be preserved
      expect(state.filters.status, 'new');
      expect(state.filters.candidatesOnly, true);
      expect(state.filters.sortBy, 'review_count');
      expect(state.filters.sortAscending, true);
      
      // Verify the last request had all parameters
      verify(mockDataSource.getLeadsPaginated(
        page: 1,
        perPage: anyNamed('perPage'),
        status: 'new',
        search: anyNamed('search'),
        candidatesOnly: true,
        sortBy: 'review_count',
        sortAscending: true,
      )).called(greaterThanOrEqualTo(1));
    });
    
    test('should load more pages with infinite scroll', () async {
      // Arrange
      final mockResponsePage1 = PaginatedResponse<LeadModel>(
        items: List.generate(25, (i) => 
          createTestLeadModel('${i+1}', 'Business ${i+1}')
        ),
        total: 50,
        page: 1,
        perPage: 25,
        totalPages: 2,
        hasNext: true,
        hasPrev: false,
      );
      
      final mockResponsePage2 = PaginatedResponse<LeadModel>(
        items: List.generate(25, (i) => 
          createTestLeadModel('${i+26}', 'Business ${i+26}')
        ),
        total: 50,
        page: 2,
        perPage: 25,
        totalPages: 2,
        hasNext: false,
        hasPrev: true,
      );
      
      when(mockDataSource.getLeadsPaginated(
        page: 1,
        perPage: anyNamed('perPage'),
        status: anyNamed('status'),
        search: anyNamed('search'),
        candidatesOnly: anyNamed('candidatesOnly'),
        sortBy: anyNamed('sortBy'),
        sortAscending: anyNamed('sortAscending'),
      )).thenAnswer((_) async => mockResponsePage1);
      
      when(mockDataSource.getLeadsPaginated(
        page: 2,
        perPage: anyNamed('perPage'),
        status: anyNamed('status'),
        search: anyNamed('search'),
        candidatesOnly: anyNamed('candidatesOnly'),
        sortBy: anyNamed('sortBy'),
        sortAscending: anyNamed('sortAscending'),
      )).thenAnswer((_) async => mockResponsePage2);
      
      // Act - wait for initialization
      final notifier = container.read(paginatedLeadsProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 100)); // Allow initialization
      await notifier.loadInitialLeads();
      
      var state = container.read(paginatedLeadsProvider);
      expect(state.leads.length, 25);
      expect(state.hasReachedEnd, false);
      
      // Load more
      await notifier.loadMoreLeads();
      
      state = container.read(paginatedLeadsProvider);
      
      // Assert
      expect(state.leads.length, 50);
      expect(state.currentPage, 2);
      expect(state.hasReachedEnd, true);
      expect(state.leads.first.businessName, 'Business 1');
      expect(state.leads.last.businessName, 'Business 50');
    });
  });
}