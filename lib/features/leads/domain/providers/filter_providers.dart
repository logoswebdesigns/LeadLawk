import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entities/filter_state.dart';
import '../repositories/filter_repository.dart';
import '../usecases/manage_filter_state.dart';
import '../../data/repositories/filter_repository_impl.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/debug_logger.dart';

// Provider for SharedPreferences (future)
final sharedPreferencesFutureProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

// Provider for FilterRepository - waits for SharedPreferences
final filterRepositoryProvider = FutureProvider<FilterRepository>((ref) async {
  final sharedPrefs = await ref.watch(sharedPreferencesFutureProvider.future);
  return FilterRepositoryImpl(sharedPrefs);
});

// Use case providers
final getFilterStateProvider = FutureProvider<GetFilterState>((ref) async {
  final repository = await ref.watch(filterRepositoryProvider.future);
  return GetFilterState(repository);
});

final updateFilterStateProvider = FutureProvider<UpdateFilterState>((ref) async {
  final repository = await ref.watch(filterRepositoryProvider.future);
  return UpdateFilterState(repository);
});

final getSortStateProvider = FutureProvider<GetSortState>((ref) async {
  final repository = await ref.watch(filterRepositoryProvider.future);
  return GetSortState(repository);
});

final updateSortStateProvider = FutureProvider<UpdateSortState>((ref) async {
  final repository = await ref.watch(filterRepositoryProvider.future);
  return UpdateSortState(repository);
});

final getUIStateProvider = FutureProvider<GetUIState>((ref) async {
  final repository = await ref.watch(filterRepositoryProvider.future);
  return GetUIState(repository);
});

final updateUIStateProvider = FutureProvider<UpdateUIState>((ref) async {
  final repository = await ref.watch(filterRepositoryProvider.future);
  return UpdateUIState(repository);
});

// State providers for current filter, sort, and UI states
final currentFilterStateProvider = StateNotifierProvider<FilterStateNotifier, AsyncValue<LeadsFilterState>>((ref) {
  return FilterStateNotifier(ref);
});

final currentSortStateProvider = StateNotifierProvider<SortStateNotifier, AsyncValue<SortState>>((ref) {
  return SortStateNotifier(ref);
});

final currentUIStateProvider = StateNotifierProvider<UIStateNotifier, AsyncValue<LeadsUIState>>((ref) {
  return UIStateNotifier(ref);
});

// Individual filter providers that delegate to the main filter state
final statusFilterProvider = Provider<String?>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.statusFilter,
    orElse: () => null,
  );
});

final hiddenStatusesProvider = Provider<Set<String>>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.hiddenStatuses,
    orElse: () => <String>{},
  );
});

final searchFilterProvider = Provider<String>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.searchFilter,
    orElse: () => '',
  );
});

final candidatesOnlyProvider = Provider<bool>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.candidatesOnly,
    orElse: () => false,
  );
});

final calledTodayProvider = Provider<bool>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.calledToday,
    orElse: () => false,
  );
});

final locationFilterProvider = Provider<String?>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.locationFilter,
    orElse: () => null,
  );
});

final industryFilterProvider = Provider<String?>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.industryFilter,
    orElse: () => null,
  );
});

final followUpFilterProvider = Provider<String?>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.followUpFilter,
    orElse: () => null,
  );
});

final hasWebsiteFilterProvider = Provider<bool?>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.hasWebsiteFilter,
    orElse: () => null,
  );
});

final meetsRatingFilterProvider = Provider<bool?>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.meetsRatingFilter,
    orElse: () => null,
  );
});

final hasRecentReviewsFilterProvider = Provider<bool?>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.hasRecentReviewsFilter,
    orElse: () => null,
  );
});

final pageSpeedFilterProvider = Provider<String?>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.pageSpeedFilter,
    orElse: () => null,
  );
});

final ratingRangeFilterProvider = Provider<String?>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.ratingRangeFilter,
    orElse: () => null,
  );
});

final reviewCountRangeFilterProvider = Provider<String?>((ref) {
  return ref.watch(currentFilterStateProvider).maybeWhen(
    data: (filterState) => filterState.reviewCountRangeFilter,
    orElse: () => null,
  );
});

final sortStateProvider = Provider<SortState>((ref) {
  return ref.watch(currentSortStateProvider).maybeWhen(
    data: (sortState) => sortState,
    orElse: () => const SortState(),
  );
});

final selectedLeadsProvider = Provider<Set<String>>((ref) {
  return ref.watch(currentUIStateProvider).maybeWhen(
    data: (uiState) => uiState.selectedLeads,
    orElse: () => <String>{},
  );
});

final isSelectionModeProvider = Provider<bool>((ref) {
  return ref.watch(currentUIStateProvider).maybeWhen(
    data: (uiState) => uiState.isSelectionMode,
    orElse: () => false,
  );
});

final groupByOptionProvider = Provider<GroupByOption>((ref) {
  return ref.watch(currentUIStateProvider).maybeWhen(
    data: (uiState) => uiState.groupByOption,
    orElse: () => GroupByOption.none,
  );
});

final expandedGroupsProvider = Provider<Set<String>>((ref) {
  return ref.watch(currentUIStateProvider).maybeWhen(
    data: (uiState) => uiState.expandedGroups,
    orElse: () => <String>{},
  );
});

final pageSizeProvider = Provider<int>((ref) {
  return ref.watch(currentUIStateProvider).maybeWhen(
    data: (uiState) => uiState.pageSize,
    orElse: () => 25,
  );
});

// State notifiers to manage the states
class FilterStateNotifier extends StateNotifier<AsyncValue<LeadsFilterState>> {
  final Ref _ref;

  FilterStateNotifier(this._ref) : super(AsyncValue.loading()) {
    _loadInitialState();
  }

  void _loadInitialState() async {
    try {
      final getFilterState = await _ref.read(getFilterStateProvider.future);
      final result = await getFilterState(NoParams());
      result.fold(
        (failure) => state = AsyncValue.error(failure, StackTrace.current),
        (filterState) {
          // Clear the status filter on load to prevent stale "interested" filter from persisting
          final cleanFilterState = filterState.copyWith(
            statusFilter: null,  // Always start with no status filter
            hiddenStatuses: const {},  // Clear hidden statuses too
          );
          state = AsyncValue.data(cleanFilterState);
          
          // Also update the persisted state to remove the stale filter
          if (filterState.statusFilter != null || filterState.hiddenStatuses.isNotEmpty) {
            // Save the clean state back to persistence
            updateFilterState(cleanFilterState);
          }
        },
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateFilterState(LeadsFilterState filterState) async {
    try {
      final updateFilterState = await _ref.read(updateFilterStateProvider.future);
      final result = await updateFilterState(UpdateFilterStateParams(filterState: filterState));
      result.fold(
        (failure) => state = AsyncValue.error(failure, StackTrace.current),
        (_) => state = AsyncValue.data(filterState),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateStatusFilter(String? status) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(statusFilter: status);
      await updateFilterState(updatedState);
    });
  }

  Future<void> updateSearchFilter(String search) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(searchFilter: search);
      await updateFilterState(updatedState);
    });
  }

  Future<void> updateCandidatesOnly(bool candidatesOnly) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(candidatesOnly: candidatesOnly);
      await updateFilterState(updatedState);
    });
  }

  Future<void> updateCalledToday(bool calledToday) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(calledToday: calledToday);
      await updateFilterState(updatedState);
    });
  }

  Future<void> toggleHiddenStatus(String status) async {
    state.whenData((currentState) async {
      final hiddenStatuses = Set<String>.from(currentState.hiddenStatuses);
      if (hiddenStatuses.contains(status)) {
        hiddenStatuses.remove(status);
      } else {
        hiddenStatuses.add(status);
      }
      final updatedState = currentState.copyWith(hiddenStatuses: hiddenStatuses);
      await updateFilterState(updatedState);
    });
  }

  Future<void> updateLocationFilter(String? location) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(locationFilter: location);
      await updateFilterState(updatedState);
    });
  }

  Future<void> updateIndustryFilter(String? industry) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(industryFilter: industry);
      await updateFilterState(updatedState);
    });
  }

  Future<void> updateFollowUpFilter(String? followUp) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(followUpFilter: followUp);
      await updateFilterState(updatedState);
    });
  }

  Future<void> updateHasWebsiteFilter(bool? hasWebsite) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(hasWebsiteFilter: hasWebsite);
      await updateFilterState(updatedState);
    });
  }

  Future<void> updateMeetsRatingFilter(bool? meetsRating) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(meetsRatingFilter: meetsRating);
      await updateFilterState(updatedState);
    });
  }

  Future<void> updateHasRecentReviewsFilter(bool? hasRecentReviews) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(hasRecentReviewsFilter: hasRecentReviews);
      await updateFilterState(updatedState);
    });
  }

  Future<void> updatePageSpeedFilter(String? pageSpeed) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(pageSpeedFilter: pageSpeed);
      await updateFilterState(updatedState);
    });
  }

  Future<void> updateRatingRangeFilter(String? ratingRange) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(ratingRangeFilter: ratingRange);
      await updateFilterState(updatedState);
    });
  }

  Future<void> updateReviewCountRangeFilter(String? reviewCountRange) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(reviewCountRangeFilter: reviewCountRange);
      await updateFilterState(updatedState);
    });
  }

  Future<void> clearHiddenStatuses() async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(hiddenStatuses: <String>{});
      await updateFilterState(updatedState);
    });
  }

  Future<void> resetAllFilters() async {
    // Reset to completely clean state - no filters applied
    const cleanState = LeadsFilterState(
      statusFilter: null,
      hiddenStatuses: {},
      locationFilter: null,
      industryFilter: null,
      sourceFilter: null,
      searchFilter: '',
      candidatesOnly: false,
      calledToday: false,
      followUpFilter: null,
      hasWebsiteFilter: null,
      meetsRatingFilter: null,
      hasRecentReviewsFilter: null,
      ratingRangeFilter: null,
      reviewCountRangeFilter: null,
      pageSpeedFilter: null,
    );
    await updateFilterState(cleanState);
  }

}

class SortStateNotifier extends StateNotifier<AsyncValue<SortState>> {
  final Ref _ref;

  SortStateNotifier(this._ref) : super(AsyncValue.loading()) {
    _loadInitialState();
  }

  void _loadInitialState() async {
    try {
      // Check if user has saved a default sort preference
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('default_sort_settings');
      
      if (settingsJson != null) {
        // User has set a default - use it
        final settings = json.decode(settingsJson);
        final sortOption = SortOption.values[settings['sortOption'] ?? 0];
        final sortAscending = settings['sortAscending'] ?? false;
        state = AsyncValue.data(SortState(option: sortOption, ascending: sortAscending));
        DebugLogger.log('🔄 Loaded user default sort: ${sortOption.name} (${sortAscending ? "asc" : "desc"})');
      } else {
        // No user default - use app default (Newest first, descending)
        state = AsyncValue.data(const SortState());
        DebugLogger.log('🔄 Using app default sort: newest (desc)');
      }
    } catch (e) {
      // If anything goes wrong, fall back to default
      state = AsyncValue.data(const SortState());
      DebugLogger.log('🔄 Error loading sort preference, using default: $e');
    }
  }

  Future<void> updateSortState(SortState sortState) async {
    // Just update the state in memory - don't persist to SharedPreferences
    // Sort state should be session-only
    state = AsyncValue.data(sortState);
  }

  Future<void> updateSort(SortOption option, bool ascending) async {
    final newSortState = SortState(option: option, ascending: ascending);
    await updateSortState(newSortState);
  }
}

class UIStateNotifier extends StateNotifier<AsyncValue<LeadsUIState>> {
  final Ref _ref;

  UIStateNotifier(this._ref) : super(AsyncValue.loading()) {
    _loadInitialState();
  }

  void _loadInitialState() async {
    try {
      final getUIState = await _ref.read(getUIStateProvider.future);
      final result = await getUIState(NoParams());
      result.fold(
        (failure) => state = AsyncValue.error(failure, StackTrace.current),
        (uiState) => state = AsyncValue.data(uiState),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateUIState(LeadsUIState uiState) async {
    try {
      final updateUIState = await _ref.read(updateUIStateProvider.future);
      final result = await updateUIState(UpdateUIStateParams(uiState: uiState));
      result.fold(
        (failure) => state = AsyncValue.error(failure, StackTrace.current),
        (_) => state = AsyncValue.data(uiState),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleLeadSelection(String leadId) async {
    state.whenData((currentState) async {
      final selectedLeads = Set<String>.from(currentState.selectedLeads);
      if (selectedLeads.contains(leadId)) {
        selectedLeads.remove(leadId);
      } else {
        selectedLeads.add(leadId);
      }
      final updatedState = currentState.copyWith(selectedLeads: selectedLeads);
      await updateUIState(updatedState);
    });
  }

  Future<void> clearSelections() async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(selectedLeads: <String>{});
      await updateUIState(updatedState);
    });
  }

  Future<void> toggleSelectionMode(bool enabled) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(isSelectionMode: enabled);
      await updateUIState(updatedState);
    });
  }

  Future<void> updatePageSize(int pageSize) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(pageSize: pageSize);
      await updateUIState(updatedState);
    });
  }

  Future<void> updateGroupByOption(GroupByOption option) async {
    state.whenData((currentState) async {
      final updatedState = currentState.copyWith(groupByOption: option);
      await updateUIState(updatedState);
    });
  }

  Future<void> toggleExpandedGroup(String groupKey) async {
    state.whenData((currentState) async {
      final expandedGroups = Set<String>.from(currentState.expandedGroups);
      if (expandedGroups.contains(groupKey)) {
        expandedGroups.remove(groupKey);
      } else {
        expandedGroups.add(groupKey);
      }
      final updatedState = currentState.copyWith(expandedGroups: expandedGroups);
      await updateUIState(updatedState);
    });
  }
}