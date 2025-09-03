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
import '../providers/paginated_leads_provider.dart';
import '../providers/lead_statistics_provider.dart';
import '../../data/datasources/leads_remote_datasource.dart';
import '../widgets/filter_bar.dart';
import '../widgets/conversion_pipeline.dart';
import '../widgets/active_jobs_monitor.dart';
import '../widgets/lead_tile.dart';
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

// Page size provider for pagination
final pageSizeProvider = StateProvider<int>((ref) => 25);

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
  bool _isLoadingMore = false;
  
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
    
    // Initialize WebSocket connection and refresh statistics
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pageSpeedWebSocketProvider);
      _refreshData();
      // Force statistics refresh on page load
      ref.invalidate(leadStatisticsProvider);
    });
  }
  
  
  String _getSortByField(SortOption option) {
    switch (option) {
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
  
  void _initScrollController() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > 100) {
        _storeScrollPosition();
      }
      
      // Load more when reaching the bottom
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }
  
  void _loadMore() {
    if (!_isLoadingMore) {
      print('📱 UI: Scroll triggered load more');
      setState(() => _isLoadingMore = true);
      ref.read(paginatedLeadsProvider.notifier).loadMoreLeads().then((_) {
        if (mounted) setState(() => _isLoadingMore = false);
      });
    }
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
    ref.read(paginatedLeadsProvider.notifier).refreshLeads();
    // Also refresh the statistics
    ref.invalidate(leadStatisticsProvider);
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
    // Status filter listener
    ref.listen(statusFilterProvider, (previous, next) {
      if (previous != next) {
        print('📱 UI: Status filter changed to $next');
        // Get current state of all other filters
        final search = ref.read(searchFilterProvider);
        final candidatesOnly = ref.read(candidatesOnlyProvider);
        final sortOption = ref.read(sortOptionProvider);
        final sortBy = _getSortByField(sortOption);
        final sortAscending = ref.read(sortAscendingProvider);
        
        ref.read(paginatedLeadsProvider.notifier).updateFilters(
          status: next,
          search: search.isEmpty ? null : search,
          candidatesOnly: candidatesOnly,
          sortBy: sortBy,
          sortAscending: sortAscending,
        );
      }
    });
    
    // Search filter listener with debounce
    ref.listen(searchFilterProvider, (previous, next) {
      if (previous != next) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          print('📱 UI: Search filter changed to "$next"');
          // Get current state of all other filters
          final status = ref.read(statusFilterProvider);
          final candidatesOnly = ref.read(candidatesOnlyProvider);
          final sortOption = ref.read(sortOptionProvider);
          final sortBy = _getSortByField(sortOption);
          final sortAscending = ref.read(sortAscendingProvider);
          
          ref.read(paginatedLeadsProvider.notifier).updateFilters(
            status: status,
            search: next.isEmpty ? null : next,
            candidatesOnly: candidatesOnly,
            sortBy: sortBy,
            sortAscending: sortAscending,
          );
        });
      }
    });
    
    // Candidates only filter listener
    ref.listen(candidatesOnlyProvider, (previous, next) {
      if (previous != next) {
        print('📱 UI: Candidates only filter changed to $next');
        // Get current state of all other filters
        final status = ref.read(statusFilterProvider);
        final search = ref.read(searchFilterProvider);
        final sortOption = ref.read(sortOptionProvider);
        final sortBy = _getSortByField(sortOption);
        final sortAscending = ref.read(sortAscendingProvider);
        
        ref.read(paginatedLeadsProvider.notifier).updateFilters(
          status: status,
          search: search.isEmpty ? null : search,
          candidatesOnly: next,
          sortBy: sortBy,
          sortAscending: sortAscending,
        );
      }
    });
    
    // Sort option listener
    ref.listen(sortOptionProvider, (previous, next) {
      print('📱 UI DEBUG: sortOptionProvider changed from $previous to $next');
      if (previous != next) {
        final sortBy = _getSortByField(next);
        final sortAscending = ref.read(sortAscendingProvider);
        print('📱 UI: Sort option changed to $next (sortBy: $sortBy, ascending: $sortAscending)');
        
        // Get current state of all filters
        final status = ref.read(statusFilterProvider);
        final search = ref.read(searchFilterProvider);
        final candidatesOnly = ref.read(candidatesOnlyProvider);
        
        print('📱 UI DEBUG: Calling updateFilters with status=$status, search=$search, candidatesOnly=$candidatesOnly, sortBy=$sortBy, sortAscending=$sortAscending');
        
        ref.read(paginatedLeadsProvider.notifier).updateFilters(
          status: status,
          search: search.isEmpty ? null : search,
          candidatesOnly: candidatesOnly,
          sortBy: sortBy,
          sortAscending: sortAscending,
        );
      }
    });
    
    // Sort ascending listener
    ref.listen(sortAscendingProvider, (previous, next) {
      print('📱 UI DEBUG: sortAscendingProvider listener triggered - previous: $previous, next: $next');
      if (previous != next) {
        final sortOption = ref.read(sortOptionProvider);
        final sortBy = _getSortByField(sortOption);
        print('📱 UI: Sort direction changed to ${next ? "ascending" : "descending"} (sortBy: $sortBy)');
        
        // Get current state of all filters
        final status = ref.read(statusFilterProvider);
        final search = ref.read(searchFilterProvider);
        final candidatesOnly = ref.read(candidatesOnlyProvider);
        
        ref.read(paginatedLeadsProvider.notifier).updateFilters(
          status: status,
          search: search.isEmpty ? null : search,
          candidatesOnly: candidatesOnly,
          sortBy: sortBy,
          sortAscending: next,
        );
      }
    });
    
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
        Future.microtask(() {
          _refreshData();
          // Also refresh the statistics
          ref.invalidate(leadStatisticsProvider);
        });
      }
    });
    
    final paginatedState = ref.watch(paginatedLeadsProvider);
    final pageSize = ref.watch(pageSizeProvider);
    final serverState = ref.watch(serverStatusProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          Column(
            children: [
              // Pipeline at the top - shows overall statistics
              const ConversionPipeline(),
              // Active jobs monitor
              const ActiveJobsMonitor(),
              // Filter bar with page size selector
              Column(
                children: [
                  const FilterBar(),
                  // Page size selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppTheme.elevatedSurface,
                    child: Row(
                      children: [
                        Text(
                          'Show:',
                          style: TextStyle(
                            color: AppTheme.mediumGray,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: pageSize,
                              dropdownColor: AppTheme.elevatedSurface,
                              icon: Icon(Icons.arrow_drop_down, color: AppTheme.mediumGray),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              items: [25, 50, 100, 500].map((size) {
                                return DropdownMenuItem(
                                  value: size,
                                  child: Text('$size per page'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  print('📱 UI: User changed page size to $value');
                                  ref.read(pageSizeProvider.notifier).state = value;
                                  // Update the notifier with new page size
                                  ref.read(paginatedLeadsProvider.notifier).updatePageSize(value);
                                }
                              },
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (paginatedState.total > 0)
                          Text(
                            'Total: ${paginatedState.total} leads',
                            style: TextStyle(
                              color: AppTheme.mediumGray,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // Sort bar OR Selection action bar (mutually exclusive)
              const SortBar(),
              const SelectionActionBar(),
              // Leads list
              Expanded(
                child: paginatedState.isLoading && paginatedState.leads.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : paginatedState.error != null && paginatedState.leads.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                const SizedBox(height: 16),
                                Text('Error: ${paginatedState.error}', textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _refreshData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _buildLeadsList(context, paginatedState.leads, paginatedState.isLoadingMore),
              ),
            ],
          ),
          const ServerStatusBadge(),
        ],
      ),
    );
  }
  
  Widget _buildLeadsList(BuildContext context, List<Lead> leads, bool isLoadingMore) {
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
      itemCount: leads.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == leads.length) {
          // Loading indicator at the bottom
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        final lead = leads[index];
        return LeadTile(lead: lead);
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