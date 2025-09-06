import 'package:equatable/equatable.dart';

// Enum for sort options
enum SortOption {
  newest,
  rating,
  reviews,
  alphabetical,
  pageSpeed,
  conversion,
}

// Enum for grouping options
enum GroupByOption {
  none,
  status,
  location,
  industry,
  hasWebsite,
  pageSpeed,
  rating,
}

// Extension to convert SortOption to API field names
extension SortOptionExtension on SortOption {
  String get sortField {
    switch (this) {
      case SortOption.newest:
        return 'created_at';
      case SortOption.rating:
        return 'rating';
      case SortOption.reviews:
        return 'review_count';
      case SortOption.alphabetical:
        return 'business_name';
      case SortOption.pageSpeed:
        return 'pagespeed_mobile_score';
      case SortOption.conversion:
        return 'conversion_score';
    }
  }
}

// Core filter state for leads
class LeadsFilterState extends Equatable {
  final String? statusFilter;
  final Set<String> hiddenStatuses;
  final String? locationFilter;
  final String? industryFilter;
  final String? sourceFilter;
  final String searchFilter;
  final bool candidatesOnly;
  final bool calledToday;
  final String? followUpFilter;
  final bool? hasWebsiteFilter;
  final bool? meetsRatingFilter;
  final bool? hasRecentReviewsFilter;
  final String? ratingRangeFilter;
  final String? reviewCountRangeFilter;
  final String? pageSpeedFilter;
  
  // Legacy compatibility properties for tests
  final String? status;
  final String? search;
  final String? sortBy;
  final bool? sortAscending;
  
  const LeadsFilterState({
    this.statusFilter,
    this.hiddenStatuses = const {},
    this.locationFilter,
    this.industryFilter,
    this.sourceFilter,
    this.searchFilter = '',
    this.candidatesOnly = false,
    this.calledToday = false,
    this.followUpFilter,
    this.hasWebsiteFilter,
    this.meetsRatingFilter,
    this.hasRecentReviewsFilter,
    this.ratingRangeFilter,
    this.reviewCountRangeFilter,
    this.pageSpeedFilter,
    // Legacy compatibility properties for tests
    this.status,
    this.search,
    this.sortBy,
    this.sortAscending,
  });

  LeadsFilterState copyWith({
    String? statusFilter,
    Set<String>? hiddenStatuses,
    String? locationFilter,
    String? industryFilter,
    String? sourceFilter,
    String? searchFilter,
    bool? candidatesOnly,
    bool? calledToday,
    String? followUpFilter,
    bool? hasWebsiteFilter,
    bool? meetsRatingFilter,
    bool? hasRecentReviewsFilter,
    String? ratingRangeFilter,
    String? reviewCountRangeFilter,
    String? pageSpeedFilter,
    // Legacy compatibility properties for tests
    String? status,
    String? search,
    String? sortBy,
    bool? sortAscending,
  }) {
    return LeadsFilterState(
      statusFilter: statusFilter ?? this.statusFilter,
      hiddenStatuses: hiddenStatuses ?? this.hiddenStatuses,
      locationFilter: locationFilter ?? this.locationFilter,
      industryFilter: industryFilter ?? this.industryFilter,
      sourceFilter: sourceFilter ?? this.sourceFilter,
      searchFilter: searchFilter ?? this.searchFilter,
      candidatesOnly: candidatesOnly ?? this.candidatesOnly,
      calledToday: calledToday ?? this.calledToday,
      followUpFilter: followUpFilter ?? this.followUpFilter,
      hasWebsiteFilter: hasWebsiteFilter ?? this.hasWebsiteFilter,
      meetsRatingFilter: meetsRatingFilter ?? this.meetsRatingFilter,
      hasRecentReviewsFilter: hasRecentReviewsFilter ?? this.hasRecentReviewsFilter,
      ratingRangeFilter: ratingRangeFilter ?? this.ratingRangeFilter,
      reviewCountRangeFilter: reviewCountRangeFilter ?? this.reviewCountRangeFilter,
      pageSpeedFilter: pageSpeedFilter ?? this.pageSpeedFilter,
      // Legacy compatibility properties for tests
      status: status ?? this.status,
      search: search ?? this.search,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  // Helper method to check if any filters are active
  bool get hasActiveFilters {
    return statusFilter != null ||
           hiddenStatuses.isNotEmpty ||
           locationFilter != null ||
           industryFilter != null ||
           sourceFilter != null ||
           searchFilter.isNotEmpty ||
           candidatesOnly ||
           calledToday ||
           followUpFilter != null ||
           hasWebsiteFilter != null ||
           meetsRatingFilter != null ||
           hasRecentReviewsFilter != null ||
           ratingRangeFilter != null ||
           reviewCountRangeFilter != null ||
           pageSpeedFilter != null;
  }

  // Convert to map for persistence
  Map<String, dynamic> toMap() {
    return {
      'statusFilter': statusFilter,
      'hiddenStatuses': hiddenStatuses.toList(),
      'locationFilter': locationFilter,
      'industryFilter': industryFilter,
      'sourceFilter': sourceFilter,
      'searchFilter': searchFilter,
      'candidatesOnly': candidatesOnly,
      'calledToday': calledToday,
      'followUpFilter': followUpFilter,
      'hasWebsiteFilter': hasWebsiteFilter,
      'meetsRatingFilter': meetsRatingFilter,
      'hasRecentReviewsFilter': hasRecentReviewsFilter,
      'ratingRangeFilter': ratingRangeFilter,
      'reviewCountRangeFilter': reviewCountRangeFilter,
      'pageSpeedFilter': pageSpeedFilter,
      // Legacy compatibility properties for tests
      'status': status,
      'search': search,
      'sortBy': sortBy,
      'sortAscending': sortAscending,
    };
  }

  // Create from map for persistence
  factory LeadsFilterState.fromMap(Map<String, dynamic> map) {
    return LeadsFilterState(
      statusFilter: map['statusFilter'] as String?,
      hiddenStatuses: Set<String>.from(map['hiddenStatuses'] as List? ?? []),
      locationFilter: map['locationFilter'] as String?,
      industryFilter: map['industryFilter'] as String?,
      sourceFilter: map['sourceFilter'] as String?,
      searchFilter: map['searchFilter'] as String? ?? '',
      candidatesOnly: map['candidatesOnly'] as bool? ?? false,
      calledToday: map['calledToday'] as bool? ?? false,
      followUpFilter: map['followUpFilter'] as String?,
      hasWebsiteFilter: map['hasWebsiteFilter'] as bool?,
      meetsRatingFilter: map['meetsRatingFilter'] as bool?,
      hasRecentReviewsFilter: map['hasRecentReviewsFilter'] as bool?,
      ratingRangeFilter: map['ratingRangeFilter'] as String?,
      reviewCountRangeFilter: map['reviewCountRangeFilter'] as String?,
      pageSpeedFilter: map['pageSpeedFilter'] as String?,
      // Legacy compatibility properties for tests
      status: map['status'] as String?,
      search: map['search'] as String?,
      sortBy: map['sortBy'] as String?,
      sortAscending: map['sortAscending'] as bool?,
    );
  }

  @override
  List<Object?> get props => [
        statusFilter,
        hiddenStatuses,
        locationFilter,
        industryFilter,
        sourceFilter,
        searchFilter,
        candidatesOnly,
        calledToday,
        followUpFilter,
        hasWebsiteFilter,
        meetsRatingFilter,
        hasRecentReviewsFilter,
        ratingRangeFilter,
        reviewCountRangeFilter,
        pageSpeedFilter,
        // Legacy compatibility properties for tests
        status,
        search,
        sortBy,
        sortAscending,
      ];
}

// Sort state entity  
class SortState extends Equatable {
  final SortOption option;
  final bool ascending;
  
  const SortState({
    this.option = SortOption.newest,
    this.ascending = false,
  });
  
  SortState copyWith({
    SortOption? option,
    bool? ascending,
  }) {
    return SortState(
      option: option ?? this.option,
      ascending: ascending ?? this.ascending,
    );
  }

  String get sortField => option.sortField;

  // Convert to map for persistence
  Map<String, dynamic> toMap() {
    return {
      'option': option.name,
      'ascending': ascending,
    };
  }

  // Create from map for persistence
  factory SortState.fromMap(Map<String, dynamic> map) {
    final optionName = map['option'] as String? ?? 'newest';
    final option = SortOption.values.firstWhere(
      (e) => e.name == optionName,
      orElse: () => SortOption.newest,
    );
    
    return SortState(
      option: option,
      ascending: map['ascending'] as bool? ?? false,
    );
  }
  
  @override
  List<Object?> get props => [option, ascending];
}

// UI state for selections and grouping
class LeadsUIState extends Equatable {
  final Set<String> selectedLeads;
  final bool isSelectionMode;
  final GroupByOption groupByOption;
  final Set<String> expandedGroups;
  final int pageSize;
  
  const LeadsUIState({
    this.selectedLeads = const {},
    this.isSelectionMode = false,
    this.groupByOption = GroupByOption.none,
    this.expandedGroups = const {},
    this.pageSize = 25,
  });

  LeadsUIState copyWith({
    Set<String>? selectedLeads,
    bool? isSelectionMode,
    GroupByOption? groupByOption,
    Set<String>? expandedGroups,
    int? pageSize,
  }) {
    return LeadsUIState(
      selectedLeads: selectedLeads ?? this.selectedLeads,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      groupByOption: groupByOption ?? this.groupByOption,
      expandedGroups: expandedGroups ?? this.expandedGroups,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  // Convert to map for persistence
  Map<String, dynamic> toMap() {
    return {
      'selectedLeads': selectedLeads.toList(),
      'isSelectionMode': isSelectionMode,
      'groupByOption': groupByOption.name,
      'expandedGroups': expandedGroups.toList(),
      'pageSize': pageSize,
    };
  }

  // Create from map for persistence
  factory LeadsUIState.fromMap(Map<String, dynamic> map) {
    final groupByName = map['groupByOption'] as String? ?? 'none';
    final groupByOption = GroupByOption.values.firstWhere(
      (e) => e.name == groupByName,
      orElse: () => GroupByOption.none,
    );
    
    return LeadsUIState(
      selectedLeads: Set<String>.from(map['selectedLeads'] as List? ?? []),
      isSelectionMode: map['isSelectionMode'] as bool? ?? false,
      groupByOption: groupByOption,
      expandedGroups: Set<String>.from(map['expandedGroups'] as List? ?? []),
      pageSize: map['pageSize'] as int? ?? 25,
    );
  }

  @override
  List<Object?> get props => [
        selectedLeads,
        isSelectionMode,
        groupByOption,
        expandedGroups,
        pageSize,
      ];
}