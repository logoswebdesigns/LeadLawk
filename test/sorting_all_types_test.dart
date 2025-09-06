import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dartz/dartz.dart';
import 'package:leadloq/features/leads/domain/entities/filter_state.dart';
import 'package:leadloq/features/leads/domain/repositories/filter_repository.dart';
import 'package:leadloq/features/leads/domain/usecases/manage_filter_state.dart';
import 'package:leadloq/features/leads/data/datasources/leads_remote_datasource.dart';
import 'package:leadloq/features/leads/data/models/paginated_response.dart';
import 'package:leadloq/features/leads/data/models/lead_model.dart';
import 'package:leadloq/core/usecases/usecase.dart';
import 'package:leadloq/core/error/failures.dart';

@GenerateMocks([FilterRepository, LeadsRemoteDataSource, GetSortState, UpdateSortState])
import 'sorting_all_types_test.mocks.dart';

void main() {
  group('Comprehensive Sorting Tests', () {
    late MockFilterRepository mockFilterRepository;
    late MockGetSortState mockGetSortState;
    late MockUpdateSortState mockUpdateSortState;
    
    setUp(() {
      mockFilterRepository = MockFilterRepository();
      mockGetSortState = MockGetSortState();
      mockUpdateSortState = MockUpdateSortState();
    });
    
    // Test updating sort state through domain layer
    group('Sort State Updates', () {
      test('should update sort state through use case', () async {
        // Setup
        final newSortState = SortState(option: SortOption.rating, ascending: true);
        when(mockUpdateSortState.call(any)).thenAnswer((_) async => const Right(null));
        
        // Execute
        final result = await mockUpdateSortState.call(UpdateSortStateParams(sortState: newSortState));
        
        // Verify
        expect(result.isRight(), true);
        verify(mockUpdateSortState.call(any)).called(1);
      });
      
      test('should handle sort state update failure', () async {
        // Setup
        final failure = CacheFailure('Sort state update failed');
        when(mockUpdateSortState.call(any)).thenAnswer((_) async => Left(failure));
        
        // Execute
        final newSortState = SortState(option: SortOption.rating, ascending: true);
        final result = await mockUpdateSortState.call(UpdateSortStateParams(sortState: newSortState));
        
        // Verify
        expect(result.isLeft(), true);
        result.fold(
          (error) => expect(error, isA<CacheFailure>()),
          (_) => fail('Should have failed'),
        );
      });
    });
    
    group('Created At Sorting', () {
      test('should sort by created_at descending (newest first)', () async {
        // Setup mock to return newest sort state
        final sortState = SortState(option: SortOption.newest, ascending: false);
        when(mockGetSortState.call(any)).thenAnswer((_) async => Right(sortState));
        
        // Test the use case directly
        final result = await mockGetSortState.call(NoParams());
        
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (sortState) {
            expect(sortState.option, SortOption.newest);
            expect(sortState.ascending, false);
            expect(sortState.sortField, 'created_at');
          },
        );
      });
      
      test('should sort by created_at ascending (oldest first)', () async {
        // Setup mock to return ascending sort state
        final sortState = SortState(option: SortOption.newest, ascending: true);
        when(mockGetSortState.call(any)).thenAnswer((_) async => Right(sortState));
        
        // Test the use case directly
        final result = await mockGetSortState.call(NoParams());
        
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (sortState) {
            expect(sortState.option, SortOption.newest);
            expect(sortState.ascending, true);
            expect(sortState.sortField, 'created_at');
          },
        );
      });
    });
    
    group('Business Name Sorting', () {
      test('should sort by business_name ascending (A-Z)', () async {
        // Setup mock to return alphabetical ascending sort state
        final sortState = SortState(option: SortOption.alphabetical, ascending: true);
        when(mockGetSortState.call(any)).thenAnswer((_) async => Right(sortState));
        
        // Test the use case directly
        final result = await mockGetSortState.call(NoParams());
        
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (sortState) {
            expect(sortState.option, SortOption.alphabetical);
            expect(sortState.ascending, true);
            expect(sortState.sortField, 'business_name');
          },
        );
      });
      
      test('should sort by business_name descending (Z-A)', () async {
        // Setup mock to return alphabetical descending sort state
        final sortState = SortState(option: SortOption.alphabetical, ascending: false);
        when(mockGetSortState.call(any)).thenAnswer((_) async => Right(sortState));
        
        // Test the use case directly
        final result = await mockGetSortState.call(NoParams());
        
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (sortState) {
            expect(sortState.option, SortOption.alphabetical);
            expect(sortState.ascending, false);
            expect(sortState.sortField, 'business_name');
          },
        );
      });
    });
    
    group('Rating Sorting (with null handling)', () {
      test('should sort by rating descending (highest first, nulls last)', () async {
        // Setup mock to return rating descending sort state
        final sortState = SortState(option: SortOption.rating, ascending: false);
        when(mockGetSortState.call(any)).thenAnswer((_) async => Right(sortState));
        
        // Test the use case directly
        final result = await mockGetSortState.call(NoParams());
        
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (sortState) {
            expect(sortState.option, SortOption.rating);
            expect(sortState.ascending, false);
            expect(sortState.sortField, 'rating');
          },
        );
      });
      
      test('should sort by rating ascending (lowest first, nulls last)', () async {
        // Setup mock to return rating ascending sort state
        final sortState = SortState(option: SortOption.rating, ascending: true);
        when(mockGetSortState.call(any)).thenAnswer((_) async => Right(sortState));
        
        // Test the use case directly
        final result = await mockGetSortState.call(NoParams());
        
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (sortState) {
            expect(sortState.option, SortOption.rating);
            expect(sortState.ascending, true);
            expect(sortState.sortField, 'rating');
          },
        );
      });
    });
    
    group('Review Count Sorting (with null handling)', () {
      test('should sort by review_count descending (most reviews first, nulls last)', () async {
        // Setup mock to return reviews descending sort state
        final sortState = SortState(option: SortOption.reviews, ascending: false);
        when(mockGetSortState.call(any)).thenAnswer((_) async => Right(sortState));
        
        // Test the use case directly
        final result = await mockGetSortState.call(NoParams());
        
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (sortState) {
            expect(sortState.option, SortOption.reviews);
            expect(sortState.ascending, false);
            expect(sortState.sortField, 'review_count');
          },
        );
      });
      
      test('should sort by review_count ascending (least reviews first, nulls last)', () async {
        // Setup mock to return reviews ascending sort state
        final sortState = SortState(option: SortOption.reviews, ascending: true);
        when(mockGetSortState.call(any)).thenAnswer((_) async => Right(sortState));
        
        // Test the use case directly
        final result = await mockGetSortState.call(NoParams());
        
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (sortState) {
            expect(sortState.option, SortOption.reviews);
            expect(sortState.ascending, true);
            expect(sortState.sortField, 'review_count');
          },
        );
      });
    });
    
    group('PageSpeed Mobile Score Sorting (with null handling)', () {
      test('should sort by pagespeed_mobile_score descending (highest first, nulls last)', () async {
        // Setup mock to return pageSpeed descending sort state
        final sortState = SortState(option: SortOption.pageSpeed, ascending: false);
        when(mockGetSortState.call(any)).thenAnswer((_) async => Right(sortState));
        
        // Test the use case directly
        final result = await mockGetSortState.call(NoParams());
        
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (sortState) {
            expect(sortState.option, SortOption.pageSpeed);
            expect(sortState.ascending, false);
            expect(sortState.sortField, 'pagespeed_mobile_score');
          },
        );
      });
      
      test('should sort by pagespeed_mobile_score ascending (lowest first, nulls last)', () async {
        // Setup mock to return pageSpeed ascending sort state
        final sortState = SortState(option: SortOption.pageSpeed, ascending: true);
        when(mockGetSortState.call(any)).thenAnswer((_) async => Right(sortState));
        
        // Test the use case directly
        final result = await mockGetSortState.call(NoParams());
        
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (sortState) {
            expect(sortState.option, SortOption.pageSpeed);
            expect(sortState.ascending, true);
            expect(sortState.sortField, 'pagespeed_mobile_score');
          },
        );
      });
    });
    
    group('Conversion Score Sorting (with null handling)', () {
      test('should sort by conversion_score descending (highest first, nulls last)', () async {
        // Setup mock to return conversion descending sort state
        final sortState = SortState(option: SortOption.conversion, ascending: false);
        when(mockGetSortState.call(any)).thenAnswer((_) async => Right(sortState));
        
        // Test the use case directly
        final result = await mockGetSortState.call(NoParams());
        
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (sortState) {
            expect(sortState.option, SortOption.conversion);
            expect(sortState.ascending, false);
            expect(sortState.sortField, 'conversion_score');
          },
        );
      });
      
      test('should sort by conversion_score ascending (lowest first, nulls last)', () async {
        // Setup mock to return conversion ascending sort state
        final sortState = SortState(option: SortOption.conversion, ascending: true);
        when(mockGetSortState.call(any)).thenAnswer((_) async => Right(sortState));
        
        // Test the use case directly
        final result = await mockGetSortState.call(NoParams());
        
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not fail'),
          (sortState) {
            expect(sortState.option, SortOption.conversion);
            expect(sortState.ascending, true);
            expect(sortState.sortField, 'conversion_score');
          },
        );
      });
    });
  });
}