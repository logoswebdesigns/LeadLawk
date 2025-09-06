import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/domain/entities/filter_state.dart';

void main() {
  group('LeadsFilterState', () {
    test('copyWith preserves values when not specified', () {
      // Start with a filter that has values set
      const initialFilter = LeadsFilterState(
        status: 'viewed',
        search: 'test',
        candidatesOnly: true,
        sortBy: 'business_name',
        sortAscending: true,
      );
      
      // Test preserving values when not specified
      final preservedFilter = initialFilter.copyWith();
      expect(preservedFilter.status, equals('viewed'));
      expect(preservedFilter.search, equals('test'));
      expect(preservedFilter.candidatesOnly, equals(true));
      expect(preservedFilter.sortBy, equals('business_name'));
      expect(preservedFilter.sortAscending, equals(true));
      
      // Test updating some values while preserving others
      final partialFilter = initialFilter.copyWith(
        search: 'updated search',
        candidatesOnly: false,
      );
      expect(partialFilter.status, equals('viewed')); // Should be unchanged
      expect(partialFilter.search, equals('updated search'));
      expect(partialFilter.candidatesOnly, equals(false));
      expect(partialFilter.sortBy, equals('business_name')); // Should be unchanged
      expect(partialFilter.sortAscending, equals(true)); // Should be unchanged
    });
    
    test('copyWith updates non-null values correctly', () {
      const initialFilter = LeadsFilterState();
      
      final updatedFilter = initialFilter.copyWith(
        status: 'new_',
        search: 'plumber',
        candidatesOnly: true,
        sortBy: 'rating',
        sortAscending: false,
      );
      
      expect(updatedFilter.status, equals('new_'));
      expect(updatedFilter.search, equals('plumber'));
      expect(updatedFilter.candidatesOnly, equals(true));
      expect(updatedFilter.sortBy, equals('rating'));
      expect(updatedFilter.sortAscending, equals(false));
    });
  });
}