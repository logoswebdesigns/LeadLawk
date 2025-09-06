import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lead.dart';
import 'paginated_leads_provider.dart';
import '../../../../core/utils/debug_logger.dart';

class LeadNavigationContext {
  final Lead currentLead;
  final Lead? previousLead;
  final Lead? nextLead;
  final int currentIndex;
  final int totalCount;

  LeadNavigationContext({
    required this.currentLead,
    this.previousLead,
    this.nextLead,
    required this.currentIndex,
    required this.totalCount,
  });
}

// Cached navigation provider that reuses filtered leads from memory
final leadNavigationProvider = Provider.family<LeadNavigationContext?, String>(
  (ref, currentLeadId) {
    // Get both the paginated state (for hasReachedEnd) and filtered state (for actual leads)
    final paginatedState = ref.watch(paginatedLeadsProvider);
    final filteredState = ref.watch(filteredPaginatedLeadsProvider);
    final allFilteredLeads = filteredState.leads;
    
    // If we're still loading initial data, return null
    if (filteredState.isLoading && allFilteredLeads.isEmpty) {
      // Unless we're navigating directly to a lead, then trigger initial load
      if (!paginatedState.isLoading && paginatedState.leads.isEmpty) {
        DebugLogger.navigation('🧭 NAVIGATION: No leads loaded, triggering initial load');
        Future.microtask(() {
          ref.read(paginatedLeadsProvider.notifier).loadInitialLeads();
        });
      }
      return null;
    }
    
    // Check if we need to load more leads to find the current one
    // This handles the case where user navigates directly to a lead detail page
    final currentIndex = allFilteredLeads.indexWhere((lead) => lead.id == currentLeadId);
    
    if (currentIndex == -1) {
      // Current lead not in the filtered list
      // This could mean:
      // 1. The lead is filtered out by current filters
      // 2. The lead hasn't been loaded yet (pagination)
      // 3. The lead doesn't exist
      
      // For now, return null to indicate loading state
      // The UI should handle this gracefully
      return null;
    }
    
    // Determine if we can navigate to previous/next
    // We have a next lead if:
    // 1. There's a lead in memory after this one, OR
    // 2. We haven't reached the end of all pages yet
    final hasNextInMemory = currentIndex < allFilteredLeads.length - 1;
    final hasMoreToLoad = !paginatedState.hasReachedEnd; // Use paginated state for this check
    
    // Build navigation context from the cached filtered leads
    final context = LeadNavigationContext(
      currentLead: allFilteredLeads[currentIndex],
      previousLead: currentIndex > 0 ? allFilteredLeads[currentIndex - 1] : null,
      nextLead: hasNextInMemory ? allFilteredLeads[currentIndex + 1] : null, // Set to null when no next in memory
      currentIndex: currentIndex + 1, // 1-based for display
      totalCount: paginatedState.total, // Use unfiltered total to show true count
    );
    
    DebugLogger.navigation('🧭 NAVIGATION: Lead ${currentIndex + 1}/${paginatedState.total} (filtered: ${filteredState.total}) | '
          'hasNextInMemory: $hasNextInMemory | hasMoreToLoad: $hasMoreToLoad | '
          'hasReachedEnd: ${paginatedState.hasReachedEnd} | loadedCount: ${paginatedState.leads.length}');
    
    return context;
  },
);

// Provider to handle navigation actions and load more if needed
final leadNavigationActionsProvider = Provider((ref) => LeadNavigationActions(ref));

class LeadNavigationActions {
  final Ref _ref;
  
  LeadNavigationActions(this._ref);
  
  Future<String?> navigateToNext(String currentLeadId) async {
    final navigation = _ref.read(leadNavigationProvider(currentLeadId));
    if (navigation == null) {
      DebugLogger.navigation('📊 NAVIGATION: No navigation context available');
      return null;
    }
    
    DebugLogger.navigation('📊 NAVIGATION ACTION: Current ${navigation.currentIndex}/${navigation.totalCount}, nextLead: ${navigation.nextLead?.businessName ?? "null"}');
    
    // If we have a next lead in memory, use it
    if (navigation.nextLead != null && navigation.nextLead!.id != currentLeadId) {
      DebugLogger.navigation('📊 NAVIGATION: Using next lead from memory: ${navigation.nextLead!.businessName}');
      return navigation.nextLead!.id;
    }
    
    // Check if we're at the end of loaded leads but not at the end of all leads
    final paginatedState = _ref.read(paginatedLeadsProvider);
    final filteredState = _ref.read(filteredPaginatedLeadsProvider);
    final currentIndex = filteredState.leads.indexWhere((lead) => lead.id == currentLeadId);
    final isAtEndOfLoaded = currentIndex == filteredState.leads.length - 1;
    
    DebugLogger.navigation('📊 NAVIGATION: At index $currentIndex of ${filteredState.leads.length} loaded (total: ${paginatedState.total})');
    DebugLogger.navigation('📊 NAVIGATION: hasReachedEnd: ${paginatedState.hasReachedEnd}, isLoadingMore: ${paginatedState.isLoadingMore}');
    DebugLogger.navigation('📊 NAVIGATION: Current page: ${paginatedState.currentPage}/${paginatedState.totalPages}');
    
    // If we're at the end of loaded leads but there are more to load
    if (isAtEndOfLoaded && !paginatedState.hasReachedEnd && !paginatedState.isLoadingMore) {
      DebugLogger.navigation('📊 NAVIGATION: At end of loaded batch, loading more...');
      
      try {
        // Load the next page
        await _ref.read(paginatedLeadsProvider.notifier).loadMoreLeads();
        
        // Wait a bit for the state to update
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Get the updated state
        final updatedFiltered = _ref.read(filteredPaginatedLeadsProvider);
        final updatedPaginated = _ref.read(paginatedLeadsProvider);
        
        DebugLogger.navigation('📊 NAVIGATION: After loading - now have ${updatedFiltered.leads.length} leads (was ${filteredState.leads.length})');
        
        // Find the current lead again in case indices changed
        final newCurrentIndex = updatedFiltered.leads.indexWhere((lead) => lead.id == currentLeadId);
        
        if (newCurrentIndex != -1 && newCurrentIndex < updatedFiltered.leads.length - 1) {
          final nextLead = updatedFiltered.leads[newCurrentIndex + 1];
          DebugLogger.navigation('📊 NAVIGATION: Found next lead after loading: ${nextLead.businessName}');
          return nextLead.id;
        } else if (updatedPaginated.hasReachedEnd) {
          DebugLogger.navigation('📊 NAVIGATION: Loaded more but now at end of all leads');
        } else {
          DebugLogger.navigation('📊 NAVIGATION: Loaded more but still no next lead found');
        }
      } catch (e) {
        DebugLogger.navigation('📊 NAVIGATION ERROR: Failed to load more leads: $e');
      }
    } else if (paginatedState.hasReachedEnd) {
      DebugLogger.navigation('📊 NAVIGATION: Already at end of all leads');
    } else if (paginatedState.isLoadingMore) {
      DebugLogger.navigation('📊 NAVIGATION: Already loading more leads, please wait');
    }
    
    return null;
  }
  
  Future<String?> navigateToPrevious(String currentLeadId) async {
    final navigation = _ref.read(leadNavigationProvider(currentLeadId));
    return navigation?.previousLead?.id;
  }
}

// Helper provider to ensure all leads are loaded for navigation
// This will progressively load all pages in the background only when needed
final leadNavigationLoaderProvider = FutureProvider<void>((ref) async {
  final paginatedNotifier = ref.read(paginatedLeadsProvider.notifier);
  var currentState = ref.read(paginatedLeadsProvider);
  
  // If we've already loaded all leads, nothing to do
  if (currentState.hasReachedEnd) {
    DebugLogger.navigation('📊 NAVIGATION: All leads already loaded (${currentState.leads.length} total)');
    return;
  }
  
  DebugLogger.navigation('📊 NAVIGATION: Starting background load of remaining leads...');
  int pagesLoaded = 0;
  
  // Load remaining pages in the background
  while (!currentState.hasReachedEnd) {
    await paginatedNotifier.loadMoreLeads();
    pagesLoaded++;
    currentState = ref.read(paginatedLeadsProvider);
    
    if (currentState.hasReachedEnd) {
      DebugLogger.navigation('📊 NAVIGATION: Finished loading all leads. Loaded $pagesLoaded additional pages (${currentState.leads.length} total leads)');
      break;
    }
    
    if (currentState.error != null) {
      DebugLogger.navigation('📊 NAVIGATION ERROR: Failed to load all leads: ${currentState.error}');
      break;
    }
    
    // Add a small delay to avoid overwhelming the server
    await Future.delayed(const Duration(milliseconds: 100));
  }
});