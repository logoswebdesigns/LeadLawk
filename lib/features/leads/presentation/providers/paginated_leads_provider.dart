import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/lead.dart';
import '../../data/datasources/leads_remote_datasource.dart';
import '../../data/models/paginated_response.dart';
import '../../data/models/lead_model.dart';
import 'job_provider.dart' show leadsRemoteDataSourceProvider, dioProvider;
import '../pages/leads_list_page.dart' show hiddenStatusesProvider;

// Helper class for handling explicit null values in copyWith
class _Undefined {
  const _Undefined();
}

// Filter state that persists across pagination
class LeadsFilterState {
  final String? status;
  final String? search;
  final bool? candidatesOnly;
  final bool? calledToday;
  final String sortBy;
  final bool sortAscending;
  
  const LeadsFilterState({
    this.status,
    this.search,
    this.candidatesOnly,
    this.calledToday,
    this.sortBy = 'created_at',
    this.sortAscending = false,
  });
  
  LeadsFilterState copyWith({
    Object? status = const _Undefined(),
    Object? search = const _Undefined(),
    Object? candidatesOnly = const _Undefined(),
    Object? calledToday = const _Undefined(),
    Object? sortBy = const _Undefined(),
    Object? sortAscending = const _Undefined(),
  }) {
    return LeadsFilterState(
      status: status is _Undefined ? this.status : status as String?,
      search: search is _Undefined ? this.search : search as String?,
      candidatesOnly: candidatesOnly is _Undefined ? this.candidatesOnly : candidatesOnly as bool?,
      calledToday: calledToday is _Undefined ? this.calledToday : calledToday as bool?,
      // Fix: Don't reset to 'created_at' when null is passed - keep current value
      sortBy: sortBy is _Undefined ? this.sortBy : (sortBy as String? ?? this.sortBy),
      // Fix: Don't reset to false when null is passed - keep current value  
      sortAscending: sortAscending is _Undefined ? this.sortAscending : (sortAscending as bool? ?? this.sortAscending),
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

// Provider for the remote data source and Dio are imported from job_provider.dart

// Main provider for paginated leads
final paginatedLeadsProvider = StateNotifierProvider<PaginatedLeadsNotifier, PaginatedLeadsState>((ref) {
  final dataSource = ref.watch(leadsRemoteDataSourceProvider);
  return PaginatedLeadsNotifier(dataSource);
});

// Filtered provider that applies hidden statuses filter
final filteredPaginatedLeadsProvider = Provider<PaginatedLeadsState>((ref) {
  final paginatedState = ref.watch(paginatedLeadsProvider);
  final hiddenStatuses = ref.watch(hiddenStatusesProvider);
  
  // If no hidden statuses, return original state
  if (hiddenStatuses.isEmpty) {
    return paginatedState;
  }
  
  // Filter out hidden statuses from the leads
  final filteredLeads = paginatedState.leads.where((lead) {
    // Get the enum name (e.g., LeadStatus.new_ -> "new_", LeadStatus.called -> "called")
    final statusString = lead.status.name;
    return !hiddenStatuses.contains(statusString);
  }).toList();
  
  // Return new state with filtered leads
  // Keep the original total from the API - it represents ALL leads that match the query
  // The filtered leads are just what we've loaded and then client-side filtered
  return paginatedState.copyWith(
    leads: filteredLeads,
    // Don't change the total - it should remain the API's total count
  );
});

class PaginatedLeadsNotifier extends StateNotifier<PaginatedLeadsState> {
  final LeadsRemoteDataSource _dataSource;
  int _perPage = 25;
  
  PaginatedLeadsNotifier(this._dataSource) : super(const PaginatedLeadsState()) {
    loadInitialLeads();
  }
  
  Future<void> loadInitialLeads() async {
    if (state.isLoading) return;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // If calledToday filter is active, use the special endpoint
      final PaginatedResponse<LeadModel> response;
      if (state.filters.calledToday == true) {
        print('📊 PAGINATION: Using called-today endpoint');
        response = await _dataSource.getLeadsCalledToday(
          page: 1,
          perPage: _perPage,
        );
      } else {
        response = await _dataSource.getLeadsPaginated(
          page: 1,
          perPage: _perPage,
          status: state.filters.status,
          search: state.filters.search,
          candidatesOnly: state.filters.candidatesOnly,
          sortBy: state.filters.sortBy,
          sortAscending: state.filters.sortAscending,
        );
      }
      
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
    } catch (e) {
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
      // If calledToday filter is active, use the special endpoint
      final PaginatedResponse<LeadModel> response;
      if (state.filters.calledToday == true) {
        print('📊 PAGINATION: Using called-today endpoint for page $nextPage');
        response = await _dataSource.getLeadsCalledToday(
          page: nextPage,
          perPage: _perPage,
        );
      } else {
        response = await _dataSource.getLeadsPaginated(
          page: nextPage,
          perPage: _perPage,
          status: state.filters.status,
          search: state.filters.search,
          candidatesOnly: state.filters.candidatesOnly,
          sortBy: state.filters.sortBy,
          sortAscending: state.filters.sortAscending,
        );
      }
      
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
    state = state.copyWith(
      leads: [],
      currentPage: 1,
      hasReachedEnd: false,
    );
    await loadInitialLeads();
  }
  
  // Update filters and reload
  Future<void> updateFilters({
    Object? status = const _Undefined(),
    Object? search = const _Undefined(),
    Object? candidatesOnly = const _Undefined(),
    Object? calledToday = const _Undefined(),
    Object? sortBy = const _Undefined(),
    Object? sortAscending = const _Undefined(),
  }) async {
    print('📊 PAGINATION: updateFilters called with:');
    print('  sortBy: ${sortBy is _Undefined ? "undefined" : sortBy}');
    print('  sortAscending: ${sortAscending is _Undefined ? "undefined" : sortAscending}');
    
    // When only updating sort parameters, preserve existing filter values
    // Only pass values that were explicitly provided (not _Undefined)
    final newFilters = state.filters.copyWith(
      status: status,
      search: search,
      candidatesOnly: candidatesOnly,
      calledToday: calledToday,
      sortBy: sortBy,
      sortAscending: sortAscending,
    );
    
    print('📊 PAGINATION: After copyWith, filters are:');
    print('  sortBy: ${newFilters.sortBy}');
    print('  sortAscending: ${newFilters.sortAscending}');
    
    // If calledToday filter is being toggled, clear other filters but preserve sort settings
    final adjustedFilters = newFilters.calledToday == true 
        ? newFilters.copyWith(
            status: null,  // Clear status filter
            search: null,  // Clear search filter
            candidatesOnly: null,  // Clear candidates filter
            // sortBy and sortAscending are intentionally NOT cleared
          )
        : newFilters;
    
    // Check if filters actually changed
    final filtersChanged = 
        adjustedFilters.status != state.filters.status ||
        adjustedFilters.search != state.filters.search ||
        adjustedFilters.candidatesOnly != state.filters.candidatesOnly ||
        adjustedFilters.calledToday != state.filters.calledToday ||
        adjustedFilters.sortBy != state.filters.sortBy ||
        adjustedFilters.sortAscending != state.filters.sortAscending;
    
    if (!filtersChanged) {
      return;
    }
    
    // Update state with new filters FIRST
    state = state.copyWith(filters: adjustedFilters);
    // Then refresh the leads with the updated filters
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