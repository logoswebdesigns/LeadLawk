import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/presentation/providers/paginated_leads_provider.dart';

void main() {
  group('LeadsFilterState', () {
    test('copyWith handles explicit null values correctly', () {
      // Start with a filter that has a status set
      const initialFilter = LeadsFilterState(
        status: 'viewed',
        search: 'test',
        candidatesOnly: true,
        sortBy: 'business_name',
        sortAscending: true,
      );
      
      // Test setting status to null (switching to "all")
      final nullStatusFilter = initialFilter.copyWith(status: null);
      expect(nullStatusFilter.status, isNull);
      expect(nullStatusFilter.search, equals('test')); // Should be unchanged
      expect(nullStatusFilter.candidatesOnly, equals(true)); // Should be unchanged
      
      // Test setting search to null
      final nullSearchFilter = initialFilter.copyWith(search: null);
      expect(nullSearchFilter.status, equals('viewed')); // Should be unchanged
      expect(nullSearchFilter.search, isNull);
      
      // Test setting candidatesOnly to null
      final nullCandidatesFilter = initialFilter.copyWith(candidatesOnly: null);
      expect(nullCandidatesFilter.candidatesOnly, isNull);
      
      // Test preserving values when not specified
      final preservedFilter = initialFilter.copyWith();
      expect(preservedFilter.status, equals('viewed'));
      expect(preservedFilter.search, equals('test'));
      expect(preservedFilter.candidatesOnly, equals(true));
      expect(preservedFilter.sortBy, equals('business_name'));
      expect(preservedFilter.sortAscending, equals(true));
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