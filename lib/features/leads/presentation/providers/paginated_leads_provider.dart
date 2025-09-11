import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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
  final List<String>? statuses;  // Support multiple statuses
  final String? search;
  final bool? candidatesOnly;
  final bool? calledToday;
  final String sortBy;
  final bool sortAscending;
  
  const ApiFilterState({
    this.status,
    this.statuses,  // Support multiple statuses
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
          statuses == other.statuses &&
          search == other.search &&
          candidatesOnly == other.candidatesOnly &&
          calledToday == other.calledToday &&
          sortBy == other.sortBy &&
          sortAscending == other.sortAscending;

  @override
  int get hashCode =>
      status.hashCode ^
      statuses.hashCode ^
      search.hashCode ^
      candidatesOnly.hashCode ^
      calledToday.hashCode ^
      sortBy.hashCode ^
      sortAscending.hashCode;
  
  ApiFilterState copyWith({
    Object? status = const _Undefined(),
    Object? statuses = const _Undefined(),
    Object? search = const _Undefined(),
    Object? candidatesOnly = const _Undefined(),
    Object? calledToday = const _Undefined(),
    Object? sortBy = const _Undefined(),
    Object? sortAscending = const _Undefined(),
  }) {
    return ApiFilterState(
      status: status is _Undefined ? this.status : status as String?,
      statuses: statuses is _Undefined ? this.statuses : statuses as List<String>?,
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
      // Don't set statuses here - let the caller handle it
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
    this.filters = const ApiFilterState(
      // Default to showing NEW and VIEWED leads
      statuses: ['new_', 'viewed'],
    ),
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
  int _perPage = 500;
  bool _isInitialized = false;
  
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
      next.whenData((sortState) async {
        await _syncWithDomainState();
        // Refresh leads when sort changes
        if (previous?.hasValue == true && previous?.value != sortState) {
          refreshLeads();
        }
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
    
    // Wait for domain sort state to be initialized (includes loading user defaults)
    int retries = 0;
    while (retries < 10) {
      final sortStateAsync = _ref.read(currentSortStateProvider);
      if (sortStateAsync.hasValue) {
        final sortState = sortStateAsync.value!;
        DebugLogger.log('📊 Sort state ready: ${sortState.option.name} (${sortState.ascending ? "asc" : "desc"})');
        
        // Apply the sort state immediately to our filters
        state = state.copyWith(
          filters: state.filters.copyWith(
            sortBy: sortState.sortField,
            sortAscending: sortState.ascending,
          ),
        );
        DebugLogger.log('📊 Applied sort to filters: ${state.filters.sortBy} (${state.filters.sortAscending ? "asc" : "desc"})');
        break;
      }
      await Future.delayed(Duration(milliseconds: 50));
      retries++;
    }
    
    // Load and apply any saved filter defaults
    await _loadAndApplyDefaultFilters();
    
    // Now sync with domain state
    await _syncWithDomainState();
    
    // Mark as initialized
    _isInitialized = true;
    DebugLogger.log('✅ PaginatedLeadsNotifier fully initialized with sort: ${state.filters.sortBy} (${state.filters.sortAscending ? "asc" : "desc"})');
    
    // Now load initial leads
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
      
      // Create API filter state from domain states, but IGNORE status filter
      // We don't want any persisted status filters
      final cleanFilterState = filterState.copyWith(statusFilter: null);
      final apiFilters = ApiFilterState.fromDomain(cleanFilterState, sortState);
      
      // Preserve the default statuses if no specific status filter is set
      final finalFilters = apiFilters.copyWith(
        statuses: state.filters.statuses, // Keep existing statuses (including defaults)
      );
      
      // Check if filters actually changed before updating
      if (state.filters != finalFilters) {
        state = state.copyWith(filters: finalFilters);
        // Don't auto-refresh here to avoid loops, let the UI trigger refreshes
      }
    }
  }
  
  Future<void> loadInitialLeads() async {
    if (state.isLoading) return;
    
    DebugLogger.network('📊 INITIAL LOAD: Loading leads with filters:');
    DebugLogger.state('  • Status: ${state.filters.status ?? "all"}');
    DebugLogger.state('  • Statuses: ${state.filters.statuses ?? "all"}');
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
          // Only pass status if statuses is not set
          status: (state.filters.statuses == null || state.filters.statuses!.isEmpty) ? state.filters.status : null,
          statuses: state.filters.statuses,  // Pass multiple statuses
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
          // Only pass status if statuses is not set
          status: (state.filters.statuses == null || state.filters.statuses!.isEmpty) ? state.filters.status : null,
          statuses: state.filters.statuses,  // Pass multiple statuses
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
    // Wait for initialization to complete
    if (!_isInitialized) {
      DebugLogger.log('⏳ refreshLeads called before initialization complete, waiting...');
      int retries = 0;
      while (!_isInitialized && retries < 20) {
        await Future.delayed(Duration(milliseconds: 100));
        retries++;
      }
      if (!_isInitialized) {
        DebugLogger.log('❌ refreshLeads timeout waiting for initialization');
        return;
      }
      DebugLogger.log('✅ refreshLeads proceeding after initialization');
    }
    
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
    Object? statuses = const _Undefined(),  // Support multiple statuses
    Object? search = const _Undefined(),
    Object? candidatesOnly = const _Undefined(),
    Object? calledToday = const _Undefined(),
    Object? sortBy = const _Undefined(),
    Object? sortAscending = const _Undefined(),
  }) async {
    DebugLogger.log('📊 PAGINATION: updateFilters called with:');
    DebugLogger.log('  status: ${status is _Undefined ? "undefined" : status}');
    DebugLogger.log('  statuses: ${statuses is _Undefined ? "undefined" : statuses}');
    DebugLogger.log('  sortBy: ${sortBy is _Undefined ? "undefined" : sortBy}');
    DebugLogger.log('  sortAscending: ${sortAscending is _Undefined ? "undefined" : sortAscending}');
    
    // Update local filter state directly (bypassing domain state for status filters)
    final updatedFilters = state.filters.copyWith(
      status: status is _Undefined ? state.filters.status : status as String?,
      statuses: statuses is _Undefined ? state.filters.statuses : statuses as List<String>?,
      search: search is _Undefined ? state.filters.search : search as String?,
      candidatesOnly: candidatesOnly is _Undefined ? state.filters.candidatesOnly : candidatesOnly as bool?,
      calledToday: calledToday is _Undefined ? state.filters.calledToday : calledToday as bool?,
      sortBy: sortBy is _Undefined ? state.filters.sortBy : sortBy as String?,
      sortAscending: sortAscending is _Undefined ? state.filters.sortAscending : sortAscending as bool?,
    );
    
    state = state.copyWith(filters: updatedFilters);
    
    // Refresh leads with new filters
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
  
  Future<void> _loadAndApplyDefaultFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultSettingsJson = prefs.getString('default_filter_settings');
      
      if (defaultSettingsJson != null) {
        final defaultSettings = json.decode(defaultSettingsJson) as Map<String, dynamic>;
        DebugLogger.log('📋 Loading default filter settings: $defaultSettings');
        
        // Extract filter settings only (sort is handled by domain provider)
        final visibleStatusIndices = (defaultSettings['visibleStatuses'] as List?)?.cast<int>() ?? [];
        final candidatesOnly = defaultSettings['candidatesOnly'] as bool? ?? false;
        
        // Convert status indices to enum names
        List<String>? statusFilter;
        if (visibleStatusIndices.isNotEmpty && visibleStatusIndices.length < LeadStatus.values.length) {
          final visibleStatuses = visibleStatusIndices
              .map((index) => LeadStatus.values[index])
              .toList();
          statusFilter = visibleStatuses.map((s) => s.name).toList();
        }
        
        // Note: Sort settings are now handled by the domain provider's default_sort_settings
        // We don't set sortBy or sortAscending here - they come from domain state
        
        // Apply default filters to state (sort will come from domain sync)
        final defaultFilters = ApiFilterState(
          statuses: statusFilter,
          candidatesOnly: candidatesOnly,
          // sortBy and sortAscending will be set by _syncWithDomainState
        );
        
        state = state.copyWith(filters: state.filters.copyWith(
          statuses: statusFilter,
          candidatesOnly: candidatesOnly,
        ));
        DebugLogger.log('✅ Default filters applied (sort handled by domain)');
      } else {
        // No saved preferences - keep the default statuses (NEW and VIEWED)
        DebugLogger.log('📋 No saved filter preferences, using defaults: NEW and VIEWED');
        // The default statuses are already set in the initial state
      }
    } catch (e) {
      DebugLogger.log('❌ Error loading default filters: $e');
    }
  }
}