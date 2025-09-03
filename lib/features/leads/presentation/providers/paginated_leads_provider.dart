import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/lead.dart';
import '../../data/datasources/leads_remote_datasource.dart';
import '../../data/models/paginated_response.dart';
import '../../data/models/lead_model.dart';

// Helper class for handling explicit null values in copyWith
class _Undefined {
  const _Undefined();
}

// Filter state that persists across pagination
class LeadsFilterState {
  final String? status;
  final String? search;
  final bool? candidatesOnly;
  final String sortBy;
  final bool sortAscending;
  
  const LeadsFilterState({
    this.status,
    this.search,
    this.candidatesOnly,
    this.sortBy = 'created_at',
    this.sortAscending = false,
  });
  
  LeadsFilterState copyWith({
    Object? status = const _Undefined(),
    Object? search = const _Undefined(),
    Object? candidatesOnly = const _Undefined(),
    Object? sortBy = const _Undefined(),
    Object? sortAscending = const _Undefined(),
  }) {
    return LeadsFilterState(
      status: status is _Undefined ? this.status : status as String?,
      search: search is _Undefined ? this.search : search as String?,
      candidatesOnly: candidatesOnly is _Undefined ? this.candidatesOnly : candidatesOnly as bool?,
      sortBy: sortBy is _Undefined ? this.sortBy : (sortBy as String?) ?? 'created_at',
      sortAscending: sortAscending is _Undefined ? this.sortAscending : (sortAscending as bool?) ?? false,
    );
  }
}

// Pagination state
class PaginatedLeadsState {
  final List<Lead> leads;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasReachedEnd;
  final int currentPage;
  final int totalPages;
  final int total;
  final String? error;
  final LeadsFilterState filters;
  
  const PaginatedLeadsState({
    this.leads = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasReachedEnd = false,
    this.currentPage = 1,
    this.totalPages = 1,
    this.total = 0,
    this.error,
    this.filters = const LeadsFilterState(),
  });
  
  PaginatedLeadsState copyWith({
    List<Lead>? leads,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasReachedEnd,
    int? currentPage,
    int? totalPages,
    int? total,
    String? error,
    LeadsFilterState? filters,
  }) {
    return PaginatedLeadsState(
      leads: leads ?? this.leads,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      error: error,
      filters: filters ?? this.filters,
    );
  }
}

// Provider for the remote data source
final leadsRemoteDataSourceProvider = Provider<LeadsRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return LeadsRemoteDataSourceImpl(dio: dio);
});

// Provider for Dio
final dioProvider = Provider((ref) {
  return Dio();
});

// Main provider for paginated leads
final paginatedLeadsProvider = StateNotifierProvider<PaginatedLeadsNotifier, PaginatedLeadsState>((ref) {
  final dataSource = ref.watch(leadsRemoteDataSourceProvider);
  return PaginatedLeadsNotifier(dataSource);
});

class PaginatedLeadsNotifier extends StateNotifier<PaginatedLeadsState> {
  final LeadsRemoteDataSource _dataSource;
  int _perPage = 25;
  
  PaginatedLeadsNotifier(this._dataSource) : super(const PaginatedLeadsState()) {
    loadInitialLeads();
  }
  
  Future<void> loadInitialLeads() async {
    if (state.isLoading) return;
    
    print('📊 PAGINATION: Starting initial load with page size: $_perPage');
    print('📊 PAGINATION: Filters - status: ${state.filters.status}, search: ${state.filters.search}, candidatesOnly: ${state.filters.candidatesOnly}');
    print('📊 PAGINATION: Sort - by: ${state.filters.sortBy}, ascending: ${state.filters.sortAscending}');
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _dataSource.getLeadsPaginated(
        page: 1,
        perPage: _perPage,
        status: state.filters.status,
        search: state.filters.search,
        candidatesOnly: state.filters.candidatesOnly,
        sortBy: state.filters.sortBy,
        sortAscending: state.filters.sortAscending,
      );
      
      print('📊 PAGINATION: Received response - Page 1/${response.totalPages}');
      print('📊 PAGINATION: Items received: ${response.items.length} out of ${response.total} total');
      print('📊 PAGINATION: Has next page: ${response.hasNext}');
      
      // Convert LeadModel to Lead entity
      final leads = response.items.map((model) => model.toEntity()).toList();
      
      state = state.copyWith(
        leads: leads,
        isLoading: false,
        currentPage: response.page,
        totalPages: response.totalPages,
        total: response.total,
        hasReachedEnd: !response.hasNext,
      );
      
      print('📊 PAGINATION: Initial load complete. State updated with ${leads.length} leads');
    } catch (e) {
      print('📊 PAGINATION ERROR: Failed to load initial leads: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  Future<void> loadMoreLeads() async {
    if (state.isLoadingMore || state.hasReachedEnd) {
      if (state.hasReachedEnd) {
        print('📊 PAGINATION: Already at last page, not loading more');
      }
      return;
    }
    
    final nextPage = state.currentPage + 1;
    print('📊 PAGINATION: Loading more leads - requesting page $nextPage with page size: $_perPage');
    
    state = state.copyWith(isLoadingMore: true, error: null);
    
    try {
      final response = await _dataSource.getLeadsPaginated(
        page: nextPage,
        perPage: _perPage,
        status: state.filters.status,
        search: state.filters.search,
        candidatesOnly: state.filters.candidatesOnly,
        sortBy: state.filters.sortBy,
        sortAscending: state.filters.sortAscending,
      );
      
      print('📊 PAGINATION: Received page $nextPage/${response.totalPages}');
      print('📊 PAGINATION: Items received: ${response.items.length} (Total loaded: ${state.leads.length + response.items.length}/${response.total})');
      print('📊 PAGINATION: Has next page: ${response.hasNext}');
      
      // Convert LeadModel to Lead entity
      final newLeads = response.items.map((model) => model.toEntity()).toList();
      
      state = state.copyWith(
        leads: [...state.leads, ...newLeads],
        isLoadingMore: false,
        currentPage: response.page,
        totalPages: response.totalPages,
        total: response.total,
        hasReachedEnd: !response.hasNext,
      );
      
      print('📊 PAGINATION: Load more complete. Total leads in memory: ${state.leads.length}');
    } catch (e) {
      print('📊 PAGINATION ERROR: Failed to load more leads: $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }
  
  Future<void> refreshLeads() async {
    print('📊 PAGINATION: Refreshing leads list with page size: $_perPage');
    state = state.copyWith(
      leads: [],
      currentPage: 1,
      hasReachedEnd: false,
    );
    await loadInitialLeads();
  }
  
  // Update filters and reload
  Future<void> updateFilters({
    String? status,
    String? search,
    bool? candidatesOnly,
    String? sortBy,
    bool? sortAscending,
  }) async {
    print('📊 PAGINATION DEBUG: updateFilters called with:');
    print('  status=$status, search=$search, candidatesOnly=$candidatesOnly');
    print('  sortBy=$sortBy, sortAscending=$sortAscending');
    
    // Log if this is primarily a sort change
    if (sortBy != null || sortAscending != null) {
      print('🔄 SORT CHANGE: sortBy=${sortBy ?? state.filters.sortBy} (${sortBy != null ? "changed" : "unchanged"}), ascending=${sortAscending ?? state.filters.sortAscending} (${sortAscending != null ? "changed" : "unchanged"})');
    }
    
    // When only updating sort parameters, preserve existing filter values
    // The UI should pass all current values, but if it doesn't, we preserve them
    final newFilters = state.filters.copyWith(
      status: status,
      search: search,
      candidatesOnly: candidatesOnly,
      sortBy: sortBy,
      sortAscending: sortAscending,
    );
    
    print('📊 PAGINATION: Updating filters');
    print('📊 PAGINATION: Old filters - status: ${state.filters.status}, search: ${state.filters.search}, candidatesOnly: ${state.filters.candidatesOnly}, sortBy: ${state.filters.sortBy}, sortAscending: ${state.filters.sortAscending}');
    print('📊 PAGINATION: New filters - status: ${newFilters.status}, search: ${newFilters.search}, candidatesOnly: ${newFilters.candidatesOnly}, sortBy: ${newFilters.sortBy}, sortAscending: ${newFilters.sortAscending}');
    
    // Check if filters actually changed
    final filtersChanged = 
        newFilters.status != state.filters.status ||
        newFilters.search != state.filters.search ||
        newFilters.candidatesOnly != state.filters.candidatesOnly ||
        newFilters.sortBy != state.filters.sortBy ||
        newFilters.sortAscending != state.filters.sortAscending;
    
    if (!filtersChanged) {
      print('📊 PAGINATION: Filters unchanged, skipping reload');
      return;
    }
    
    state = state.copyWith(filters: newFilters);
    await refreshLeads();
  }
  
  // Update a single lead in the list (after edit)
  void updateLead(Lead updatedLead) {
    state = state.copyWith(
      leads: state.leads.map((lead) {
        return lead.id == updatedLead.id ? updatedLead : lead;
      }).toList(),
    );
  }
  
  // Remove a lead from the list (after delete)
  void removeLead(String leadId) {
    state = state.copyWith(
      leads: state.leads.where((lead) => lead.id != leadId).toList(),
      total: state.total - 1,
    );
  }
  
  // Update page size and reload
  Future<void> updatePageSize(int newPageSize) async {
    print('📊 PAGINATION: Changing page size from $_perPage to $newPageSize');
    _perPage = newPageSize;
    await refreshLeads();
  }
}