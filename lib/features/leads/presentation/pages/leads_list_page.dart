import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/job_provider.dart';
import '../providers/pagespeed_websocket_provider.dart';
import '../providers/server_status_provider.dart';
import '../widgets/filter_bar.dart';
import '../widgets/conversion_pipeline.dart';
import '../widgets/active_jobs_monitor.dart';
import '../widgets/enhanced_lead_tile.dart';
import '../widgets/sort_bar.dart';
import '../widgets/selection_action_bar.dart';

// Sorting options
enum SortOption {
  newest,
  rating,
  reviews,
  alphabetical,
  pageSpeed,
  conversion,
}

enum GroupByOption {
  none,
  status,
  location,
  industry,
  hasWebsite,
  pageSpeed,
  rating,
}

// Filter providers
final statusFilterProvider = StateProvider<String?>((ref) => null);
final locationFilterProvider = StateProvider<String?>((ref) => null);
final industryFilterProvider = StateProvider<String?>((ref) => null);
final sourceFilterProvider = StateProvider<String?>((ref) => null);
final searchFilterProvider = StateProvider<String>((ref) => '');
final candidatesOnlyProvider = StateProvider<bool>((ref) => false);
final followUpFilterProvider = StateProvider<String?>((ref) => null);
final hasWebsiteFilterProvider = StateProvider<bool?>((ref) => null);
final meetsRatingFilterProvider = StateProvider<bool?>((ref) => null);
final hasRecentReviewsFilterProvider = StateProvider<bool?>((ref) => null);
final ratingRangeFilterProvider = StateProvider<String?>((ref) => null);
final reviewCountRangeFilterProvider = StateProvider<String?>((ref) => null);
final pageSpeedFilterProvider = StateProvider<String?>((ref) => null);
final sortOptionProvider = StateProvider<SortOption>((ref) => SortOption.newest);
final sortAscendingProvider = StateProvider<bool>((ref) => false);
final selectedLeadsProvider = StateProvider<Set<String>>((ref) => {});
final isSelectionModeProvider = StateProvider<bool>((ref) => false);
final groupByOptionProvider = StateProvider<GroupByOption>((ref) => GroupByOption.none);
final expandedGroupsProvider = StateProvider<Set<String>>((ref) => {});
final refreshTriggerProvider = StateProvider<int>((ref) => 0);

// Main leads provider
final leadsProvider = FutureProvider.autoDispose<List<Lead>>(
  (ref) async {
    print('🔄 leadsProvider: Fetching leads from repository...');
    final repository = ref.watch(leadsRepositoryProvider);
    
    // Watch refresh trigger to force refresh
    ref.watch(refreshTriggerProvider);
    
    // Get filter parameters
    final status = ref.watch(statusFilterProvider);
    final candidatesOnly = ref.watch(candidatesOnlyProvider);
    
    final result = await repository.getLeads(
      status: status,
      search: null,
      candidatesOnly: candidatesOnly,
    );
    
    return result.fold(
      (failure) => throw Exception(failure.message),
      (leads) {
        print('✅ leadsProvider: Fetched ${leads.length} leads');
        return _applyFiltersAndSort(leads, ref);
      },
    );
  },
);

// Apply filters and sorting
List<Lead> _applyFiltersAndSort(List<Lead> leads, Ref ref) {
  var filteredLeads = List<Lead>.from(leads);
  
  // Apply all filters
  final locationFilter = ref.watch(locationFilterProvider);
  final industryFilter = ref.watch(industryFilterProvider);
  final sourceFilter = ref.watch(sourceFilterProvider);
  final searchFilter = ref.watch(searchFilterProvider);
  final followUpFilter = ref.watch(followUpFilterProvider);
  final hasWebsiteFilter = ref.watch(hasWebsiteFilterProvider);
  final meetsRatingFilter = ref.watch(meetsRatingFilterProvider);
  final hasRecentReviewsFilter = ref.watch(hasRecentReviewsFilterProvider);
  final ratingRangeFilter = ref.watch(ratingRangeFilterProvider);
  final reviewCountRangeFilter = ref.watch(reviewCountRangeFilterProvider);
  final pageSpeedFilter = ref.watch(pageSpeedFilterProvider);
  final sortOption = ref.watch(sortOptionProvider);
  final sortAscending = ref.watch(sortAscendingProvider);
  
  // Location filter
  if (locationFilter != null) {
    filteredLeads = filteredLeads.where((lead) => lead.location == locationFilter).toList();
  }
  
  // Industry filter
  if (industryFilter != null) {
    filteredLeads = filteredLeads.where((lead) => lead.industry == industryFilter).toList();
  }
  
  // Source filter
  if (sourceFilter != null) {
    filteredLeads = filteredLeads.where((lead) => lead.source == sourceFilter).toList();
  }
  
  // Search filter
  if (searchFilter.isNotEmpty) {
    final searchLower = searchFilter.toLowerCase();
    filteredLeads = filteredLeads.where((lead) {
      return lead.businessName.toLowerCase().contains(searchLower) ||
             lead.phone.toLowerCase().contains(searchLower) ||
             lead.location.toLowerCase().contains(searchLower) ||
             lead.industry.toLowerCase().contains(searchLower);
    }).toList();
  }
  
  // Follow-up filter
  if (followUpFilter != null) {
    filteredLeads = filteredLeads.where((lead) {
      if (followUpFilter == 'upcoming') {
        return lead.hasUpcomingFollowUp;
      } else if (followUpFilter == 'overdue') {
        return lead.hasOverdueFollowUp;
      }
      return true;
    }).toList();
  }
  
  // Website filter
  if (hasWebsiteFilter != null) {
    filteredLeads = filteredLeads.where((lead) => lead.hasWebsite == hasWebsiteFilter).toList();
  }
  
  // Rating filter
  if (meetsRatingFilter != null) {
    filteredLeads = filteredLeads.where((lead) => lead.meetsRatingThreshold == meetsRatingFilter).toList();
  }
  
  // Recent reviews filter
  if (hasRecentReviewsFilter != null) {
    filteredLeads = filteredLeads.where((lead) => lead.hasRecentReviews == hasRecentReviewsFilter).toList();
  }
  
  // Rating range filter
  if (ratingRangeFilter != null) {
    filteredLeads = filteredLeads.where((lead) {
      final rating = lead.rating ?? 0;
      switch (ratingRangeFilter) {
        case '5':
          return rating == 5.0;
        case '4-5':
          return rating >= 4.0 && rating <= 5.0;
        case '3-4':
          return rating >= 3.0 && rating < 4.0;
        case '2-3':
          return rating >= 2.0 && rating < 3.0;
        case '1-2':
          return rating >= 1.0 && rating < 2.0;
        default:
          return true;
      }
    }).toList();
  }
  
  // Review count range filter
  if (reviewCountRangeFilter != null) {
    filteredLeads = filteredLeads.where((lead) {
      final reviewCount = lead.reviewCount ?? 0;
      switch (reviewCountRangeFilter) {
        case '100+':
          return reviewCount >= 100;
        case '50-99':
          return reviewCount >= 50 && reviewCount < 100;
        case '20-49':
          return reviewCount >= 20 && reviewCount < 50;
        case '5-19':
          return reviewCount >= 5 && reviewCount < 20;
        case '1-4':
          return reviewCount >= 1 && reviewCount < 5;
        default:
          return true;
      }
    }).toList();
  }
  
  // PageSpeed filter
  if (pageSpeedFilter != null) {
    filteredLeads = filteredLeads.where((lead) {
      final score = lead.pagespeedMobileScore ?? lead.pagespeedDesktopScore;
      switch (pageSpeedFilter) {
        case '90+':
          return score != null && score >= 90;
        case '50-89':
          return score != null && score >= 50 && score < 90;
        case '<50':
          return score != null && score < 50;
        case 'none':
          return score == null;
        default:
          return true;
      }
    }).toList();
  }
  
  // Apply sorting
  filteredLeads.sort((a, b) {
    int comparison = 0;
    
    switch (sortOption) {
      case SortOption.newest:
        comparison = b.createdAt.compareTo(a.createdAt);
        break;
      case SortOption.rating:
        final aRating = a.rating ?? 0;
        final bRating = b.rating ?? 0;
        comparison = bRating.compareTo(aRating);
        break;
      case SortOption.reviews:
        final aReviews = a.reviewCount ?? 0;
        final bReviews = b.reviewCount ?? 0;
        comparison = bReviews.compareTo(aReviews);
        break;
      case SortOption.alphabetical:
        comparison = a.businessName.compareTo(b.businessName);
        break;
      case SortOption.pageSpeed:
        final aScore = a.pagespeedMobileScore ?? a.pagespeedDesktopScore ?? -1;
        final bScore = b.pagespeedMobileScore ?? b.pagespeedDesktopScore ?? -1;
        comparison = bScore.compareTo(aScore);
        break;
      case SortOption.conversion:
        final aScore = a.conversionScore ?? -1;
        final bScore = b.conversionScore ?? -1;
        comparison = bScore.compareTo(aScore);
        break;
    }
    
    // For newest, always sort newest first regardless of ascending flag
    if (sortOption == SortOption.newest) {
      return comparison;
    }
    return sortAscending ? comparison : -comparison;
  });
  
  return filteredLeads;
}

// Main page widget
class LeadsListPage extends ConsumerStatefulWidget {
  final String? initialFilter;
  
  const LeadsListPage({super.key, this.initialFilter});
  
  @override
  ConsumerState<LeadsListPage> createState() => _LeadsListPageState();
}

class _LeadsListPageState extends ConsumerState<LeadsListPage> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounceTimer;
  String? _lastIndustry;
  String? _lastLocation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize filters
    if (widget.initialFilter == 'candidates') {
      Future.microtask(() {
        ref.read(candidatesOnlyProvider.notifier).state = true;
      });
    }
    
    _loadLastScrapeContext();
    _initScrollController();
    
    // Initialize WebSocket connection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pageSpeedWebSocketProvider);
      _refreshData();
    });
  }
  
  void _initScrollController() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > 100) {
        _storeScrollPosition();
      }
    });
  }
  
  Future<void> _loadLastScrapeContext() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _lastIndustry = prefs.getString('last_industry');
        _lastLocation = prefs.getString('last_location');
      });
    }
  }
  
  void _refreshData() {
    ref.invalidate(leadsProvider);
  }
  
  Future<void> _storeScrollPosition() async {
    if (_scrollController.hasClients && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('leads_list_scroll_position', _scrollController.position.pixels);
    }
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Watch WebSocket state for new leads
    final wsState = ref.watch(pageSpeedWebSocketProvider);
    
    // Set up listener for WebSocket state changes
    ref.listen<PageSpeedWebSocketState>(pageSpeedWebSocketProvider, (previous, next) {
      final previousLeads = previous?.newLeads ?? {};
      final currentLeads = next.newLeads;
      final actuallyNewLeads = currentLeads.difference(previousLeads);
      
      if (actuallyNewLeads.isNotEmpty) {
        print('🆕 New leads detected: $actuallyNewLeads');
        print('🔄 Forcing leads refresh...');
        Future.microtask(() => ref.invalidate(leadsProvider));
      }
    });
    
    final leadsAsync = ref.watch(leadsProvider);
    final serverState = ref.watch(serverStatusProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          Column(
            children: [
              // Pipeline at the top - most prominent
              leadsAsync.when(
                data: (leads) => ConversionPipeline(leads: leads),
                loading: () => const SizedBox(height: 200),
                error: (_, __) => const SizedBox(height: 200),
              ),
              // Active jobs monitor
              const ActiveJobsMonitor(),
              // Filter bar
              const FilterBar(),
              // Sort bar OR Selection action bar (mutually exclusive)
              const SortBar(),
              const SelectionActionBar(),
              // Leads list
              Expanded(
                child: leadsAsync.when(
                  data: (leads) => _buildLeadsList(context, leads),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: $error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const ServerStatusBadge(),
        ],
      ),
    );
  }
  
  Widget _buildLeadsList(BuildContext context, List<Lead> leads) {
    if (leads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox, 
              size: 64, 
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No leads found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or start a new search',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/browser'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Start Search',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: leads.length,
      itemBuilder: (context, index) {
        final lead = leads[index];
        return EnhancedLeadTile(lead: lead);
      },
    );
  }
  
  Color _getStatusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return AppTheme.mediumGray;
      case LeadStatus.viewed:
        return AppTheme.darkGray;
      case LeadStatus.called:
        return AppTheme.warningOrange;
      case LeadStatus.interested:
        return AppTheme.primaryBlue;
      case LeadStatus.converted:
        return AppTheme.successGreen;
      case LeadStatus.didNotConvert:
        return Colors.deepOrange;
      case LeadStatus.callbackScheduled:
        return AppTheme.primaryBlue;
      case LeadStatus.doNotCall:
        return AppTheme.errorRed;
    }
  }
  
  String _getStatusLabel(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return 'NEW';
      case LeadStatus.viewed:
        return 'VIEWED';
      case LeadStatus.called:
        return 'CALLED';
      case LeadStatus.interested:
        return 'INTERESTED';
      case LeadStatus.converted:
        return 'CONVERTED';
      case LeadStatus.didNotConvert:
        return 'DID NOT CONVERT';
      case LeadStatus.callbackScheduled:
        return 'CALLBACK';
      case LeadStatus.doNotCall:
        return 'DO NOT CALL';
    }
  }
}

// Legacy Lead Card - replaced by EnhancedLeadTile
class _LeadCard extends ConsumerStatefulWidget {
  final Lead lead;
  
  const _LeadCard({required this.lead});
  
  @override
  ConsumerState<_LeadCard> createState() => _LeadCardState();
}

class _LeadCardState extends ConsumerState<_LeadCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _goldenEffectAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    
    // Animation that fades from 1.0 to 0.0 over 5 seconds
    _goldenEffectAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final wsNotifier = ref.read(pageSpeedWebSocketProvider.notifier);
    final isPendingDeletion = wsNotifier.isLeadPendingDeletion(widget.lead.id);
    final isNewlyAdded = wsNotifier.isNewLead(widget.lead.id);
    final selectedLeads = ref.watch(selectedLeadsProvider);
    final isSelected = selectedLeads.contains(widget.lead.id);
    
    // Start animation when newly added
    if (isNewlyAdded && !_animationController.isAnimating) {
      _animationController.forward();
    }
    
    return AnimatedBuilder(
      animation: _goldenEffectAnimation,
      builder: (context, child) {
        final goldenEffect = isNewlyAdded ? _goldenEffectAnimation.value : 0.0;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isPendingDeletion 
                ? Colors.red.withValues(alpha: 0.15)
                : AppTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPendingDeletion
                  ? Colors.red
                  : Color.lerp(
                      isSelected 
                          ? AppTheme.primaryGold.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.05),
                      AppTheme.primaryGold.withValues(alpha: 0.6),
                      goldenEffect,
                    )!,
              width: isPendingDeletion ? 2 : 1.0 + goldenEffect,
            ),
            boxShadow: goldenEffect > 0
                ? [
                    BoxShadow(
                      color: AppTheme.primaryGold.withValues(alpha: 0.3 * goldenEffect),
                      blurRadius: 20 * goldenEffect,
                      spreadRadius: 3 * goldenEffect,
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go('/leads/${widget.lead.id}'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Checkbox
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          final current = ref.read(selectedLeadsProvider);
                          final updated = Set<String>.from(current);
                          if (value == true) {
                            updated.add(widget.lead.id);
                          } else {
                            updated.remove(widget.lead.id);
                          }
                          ref.read(selectedLeadsProvider.notifier).state = updated;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getStatusColor(widget.lead.status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          widget.lead.businessName.isNotEmpty
                              ? widget.lead.businessName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: _getStatusColor(widget.lead.status),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.lead.businessName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.lead.location,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.mediumGray,
                            ),
                          ),
                          if (widget.lead.rating != null || widget.lead.reviewCount != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  if (widget.lead.rating != null) ...[
                                    Icon(Icons.star, size: 12, color: AppTheme.warningOrange),
                                    const SizedBox(width: 2),
                                    Text(
                                      widget.lead.rating!.toStringAsFixed(1),
                                      style: TextStyle(fontSize: 12, color: AppTheme.mediumGray),
                                    ),
                                  ],
                                  if (widget.lead.reviewCount != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${widget.lead.reviewCount} reviews)',
                                      style: TextStyle(fontSize: 12, color: AppTheme.mediumGray),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(widget.lead.status).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getStatusLabel(widget.lead.status),
                        style: TextStyle(
                          color: _getStatusColor(widget.lead.status),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Color _getStatusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return AppTheme.mediumGray;
      case LeadStatus.viewed:
        return AppTheme.darkGray;
      case LeadStatus.called:
        return AppTheme.warningOrange;
      case LeadStatus.interested:
        return AppTheme.primaryBlue;
      case LeadStatus.converted:
        return AppTheme.successGreen;
      case LeadStatus.didNotConvert:
        return Colors.deepOrange;
      case LeadStatus.callbackScheduled:
        return AppTheme.primaryBlue;
      case LeadStatus.doNotCall:
        return AppTheme.errorRed;
    }
  }
  
  String _getStatusLabel(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return 'NEW';
      case LeadStatus.viewed:
        return 'VIEWED';
      case LeadStatus.called:
        return 'CALLED';
      case LeadStatus.interested:
        return 'INTERESTED';
      case LeadStatus.converted:
        return 'CONVERTED';
      case LeadStatus.didNotConvert:
        return 'NO CONVERT';
      case LeadStatus.callbackScheduled:
        return 'CALLBACK';
      case LeadStatus.doNotCall:
        return 'DO NOT CALL';
    }
  }
}

// Server status badge widget
class ServerStatusBadge extends ConsumerWidget {
  const ServerStatusBadge({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverStatusProvider);
    
    if (serverState.status == ServerStatus.online) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: serverState.status == ServerStatus.starting
              ? Colors.orange
              : Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (serverState.status == ServerStatus.starting)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              const Icon(Icons.warning, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              serverState.status == ServerStatus.starting
                  ? 'Starting server...'
                  : 'Server disconnected',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}