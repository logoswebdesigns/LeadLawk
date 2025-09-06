import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/providers/filter_providers.dart';
import '../../data/datasources/leads_remote_datasource.dart';
import '../../data/models/paginated_response.dart';
import '../../data/models/lead_model.dart';
import 'job_provider.dart' show leadsRemoteDataSourceProvider;
import '../../../../core/utils/debug_logger.dart';

// Helper class for handling explicit null values in copyWith
class _Undefined {
  const _Undefined();
}

// Simple filter state for API calls - uses basic values from domain filter state
class ApiFilterState {
  final String? status;
  final String? search;
  final bool? candidatesOnly;
  final bool? calledToday;
  final String sortBy;
  final bool sortAscending;
  
  const ApiFilterState({
    this.status,
    this.search,
    this.candidatesOnly,
    this.calledToday,
    this.sortBy = 'created_at',
    this.sortAscending = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiFilterState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          search == other.search &&
          candidatesOnly == other.candidatesOnly &&
          calledToday == other.calledToday &&
          sortBy == other.sortBy &&
          sortAscending == other.sortAscending;

  @override
  int get hashCode =>
      status.hashCode ^
      search.hashCode ^
      candidatesOnly.hashCode ^
      calledToday.hashCode ^
      sortBy.hashCode ^
      sortAscending.hashCode;
  
  ApiFilterState copyWith({
    Object? status = const _Undefined(),
    Object? search = const _Undefined(),
    Object? candidatesOnly = const _Undefined(),
    Object? calledToday = const _Undefined(),
    Object? sortBy = const _Undefined(),
    Object? sortAscending = const _Undefined(),
  }) {
    return ApiFilterState(
      status: status is _Undefined ? this.status : status as String?,
      search: search is _Undefined ? this.search : search as String?,
      candidatesOnly: candidatesOnly is _Undefined ? this.candidatesOnly : candidatesOnly as bool?,
      calledToday: calledToday is _Undefined ? this.calledToday : calledToday as bool?,
      sortBy: sortBy is _Undefined ? this.sortBy : (sortBy as String? ?? this.sortBy),
      sortAscending: sortAscending is _Undefined ? this.sortAscending : (sortAscending as bool? ?? this.sortAscending),
    );
  }

  // Factory method to create from domain filter state and sort state
  factory ApiFilterState.fromDomain(LeadsFilterState filterState, SortState sortState) {
    return ApiFilterState(
      status: filterState.statusFilter,
      search: filterState.searchFilter.isEmpty ? null : filterState.searchFilter,
      candidatesOnly: filterState.candidatesOnly,
      calledToday: filterState.calledToday,
      sortBy: sortState.sortField,
      sortAscending: sortState.ascending,
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
  final ApiFilterState filters;
  
  PaginatedLeadsState({
    this.leads = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasReachedEnd = false,
    this.currentPage = 1,
    this.totalPages = 1,
    this.total = 0,
    this.error,
    this.filters = const ApiFilterState(),
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
    ApiFilterState? filters,
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
  return PaginatedLeadsNotifier(dataSource, ref);
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
  final Ref _ref;
  int _perPage = 25;
  
  PaginatedLeadsNotifier(this._dataSource, this._ref) : super(PaginatedLeadsState()) {
    _initializeWithDomainState();
  }

  Future<void> _initializeWithDomainState() async {
    // Listen to domain state changes
    _ref.listen<AsyncValue<LeadsFilterState>>(currentFilterStateProvider, (previous, next) {
      next.whenData((filterState) {
        _syncWithDomainState();
      });
    });
    
    _ref.listen<AsyncValue<SortState>>(currentSortStateProvider, (previous, next) {
      next.whenData((sortState) {
        _syncWithDomainState();
      });
    });
    
    _ref.listen<AsyncValue<LeadsUIState>>(currentUIStateProvider, (previous, next) {
      next.whenData((uiState) {
        final oldPageSize = _perPage;
        _perPage = uiState.pageSize;
        // If page size changed, refresh leads
        if (oldPageSize != _perPage) {
          refreshLeads();
        }
      });
    });
    
    // Initial sync and load
    await _syncWithDomainState();
    loadInitialLeads();
  }
  
  Future<void> _syncWithDomainState() async {
    // Read current domain states
    final filterStateAsync = _ref.read(currentFilterStateProvider);
    final sortStateAsync = _ref.read(currentSortStateProvider);
    final uiStateAsync = _ref.read(currentUIStateProvider);
    
    // Only sync if all states are available
    if (filterStateAsync.hasValue && sortStateAsync.hasValue && uiStateAsync.hasValue) {
      final filterState = filterStateAsync.value!;
      final sortState = sortStateAsync.value!;
      final uiState = uiStateAsync.value!;
      
      // Update page size
      _perPage = uiState.pageSize;
      
      // Create API filter state from domain states
      final apiFilters = ApiFilterState.fromDomain(filterState, sortState);
      
      // Check if filters actually changed before updating
      if (state.filters != apiFilters) {
        state = state.copyWith(filters: apiFilters);
        // Don't auto-refresh here to avoid loops, let the UI trigger refreshes
      }
    }
  }
  
  Future<void> loadInitialLeads() async {
    if (state.isLoading) return;
    
    DebugLogger.network('📊 API QUERY: Loading leads with filters:');
    DebugLogger.state('  • Status: ${state.filters.status ?? "all"}');
    DebugLogger.state('  • Search: ${state.filters.search ?? "none"}');
    DebugLogger.state('  • Candidates only: ${state.filters.candidatesOnly}');
    DebugLogger.state('  • Sort: ${state.filters.sortBy} (${state.filters.sortAscending ? "asc" : "desc"})');
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // If calledToday filter is active, use the special endpoint
      final PaginatedResponse<LeadModel> response;
      if (state.filters.calledToday == true) {
        DebugLogger.log('📊 PAGINATION: Using called-today endpoint');
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
        DebugLogger.log('📊 PAGINATION: Already at last page, not loading more');
      }
      return;
    }
    
    final nextPage = state.currentPage + 1;
    DebugLogger.network('📊 PAGINATION: Loading more leads - requesting page $nextPage with page size: $_perPage');
    
    state = state.copyWith(isLoadingMore: true, error: null);
    
    try {
      // If calledToday filter is active, use the special endpoint
      final PaginatedResponse<LeadModel> response;
      if (state.filters.calledToday == true) {
        DebugLogger.log('📊 PAGINATION: Using called-today endpoint for page $nextPage');
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
      
      DebugLogger.network('📊 PAGINATION: Received page $nextPage/${response.totalPages}');
      DebugLogger.network('📊 PAGINATION: Items received: ${response.items.length} (Total loaded: ${state.leads.length + response.items.length}/${response.total})');
      DebugLogger.network('📊 PAGINATION: Has next page: ${response.hasNext}');
      
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
      
      DebugLogger.state('📊 PAGINATION: Load more complete. Total leads in memory: ${state.leads.length}');
    } catch (e) {
      DebugLogger.error('📊 PAGINATION ERROR: Failed to load more leads: $e');
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
  
  // Update filters and reload - this now syncs back to domain state
  Future<void> updateFilters({
    Object? status = const _Undefined(),
    Object? search = const _Undefined(),
    Object? candidatesOnly = const _Undefined(),
    Object? calledToday = const _Undefined(),
    Object? sortBy = const _Undefined(),
    Object? sortAscending = const _Undefined(),
  }) async {
    DebugLogger.log('📊 PAGINATION: updateFilters called with:');
    DebugLogger.log('  sortBy: ${sortBy is _Undefined ? "undefined" : sortBy}');
    DebugLogger.log('  sortAscending: ${sortAscending is _Undefined ? "undefined" : sortAscending}');
    
    // Update domain state
    await _updateDomainState(
      status: status,
      search: search,
      candidatesOnly: candidatesOnly,
      calledToday: calledToday,
      sortBy: sortBy,
      sortAscending: sortAscending,
    );
    
    // Refresh leads with current filters
    await refreshLeads();
  }

  Future<void> _updateDomainState({
    Object? status = const _Undefined(),
    Object? search = const _Undefined(),
    Object? candidatesOnly = const _Undefined(),
    Object? calledToday = const _Undefined(),
    Object? sortBy = const _Undefined(),
    Object? sortAscending = const _Undefined(),
  }) async {
    // Update filter state in domain
    final currentFilterAsync = _ref.read(currentFilterStateProvider);
    if (currentFilterAsync.hasValue) {
      final currentFilter = currentFilterAsync.value!;
      
      final updatedFilter = LeadsFilterState(
        statusFilter: status is _Undefined ? currentFilter.statusFilter : status as String?,
        searchFilter: search is _Undefined ? currentFilter.searchFilter : (search as String? ?? ''),
        candidatesOnly: candidatesOnly is _Undefined ? currentFilter.candidatesOnly : (candidatesOnly as bool? ?? false),
        calledToday: calledToday is _Undefined ? currentFilter.calledToday : (calledToday as bool? ?? false),
        hiddenStatuses: currentFilter.hiddenStatuses,
        // Keep other filter properties unchanged
        locationFilter: currentFilter.locationFilter,
        industryFilter: currentFilter.industryFilter,
        sourceFilter: currentFilter.sourceFilter,
        followUpFilter: currentFilter.followUpFilter,
        hasWebsiteFilter: currentFilter.hasWebsiteFilter,
        meetsRatingFilter: currentFilter.meetsRatingFilter,
        hasRecentReviewsFilter: currentFilter.hasRecentReviewsFilter,
        ratingRangeFilter: currentFilter.ratingRangeFilter,
        reviewCountRangeFilter: currentFilter.reviewCountRangeFilter,
        pageSpeedFilter: currentFilter.pageSpeedFilter,
      );
      
      await _ref.read(currentFilterStateProvider.notifier).updateFilterState(updatedFilter);
    }
    
    // Update sort state if sort parameters were provided
    if (sortBy is! _Undefined || sortAscending is! _Undefined) {
      final currentSortAsync = _ref.read(currentSortStateProvider);
      if (currentSortAsync.hasValue) {
        final currentSort = currentSortAsync.value!;
        
        // Convert sortBy string back to SortOption if provided
        SortOption? option;
        if (sortBy is! _Undefined) {
          final sortByString = sortBy as String?;
          option = SortOption.values.firstWhere(
            (opt) => opt.sortField == sortByString,
            orElse: () => SortOption.newest,
          );
        }
        
        final updatedSort = SortState(
          option: option ?? currentSort.option,
          ascending: sortAscending is _Undefined ? currentSort.ascending : (sortAscending as bool? ?? false),
        );
        
        await _ref.read(currentSortStateProvider.notifier).updateSortState(updatedSort);
      }
    }
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
    DebugLogger.log('📊 PAGINATION: Changing page size from $_perPage to $newPageSize');
    _perPage = newPageSize;
    await refreshLeads();
  }
}