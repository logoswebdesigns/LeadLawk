import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../../domain/providers/filter_providers.dart';
import '../providers/pagespeed_websocket_provider.dart';
import '../providers/server_status_provider.dart';
import '../providers/paginated_leads_provider.dart';
import '../providers/lead_statistics_provider.dart';
import '../widgets/conversion_pipeline.dart';
import '../widgets/active_jobs_monitor.dart';
import '../widgets/lead_tile.dart';
import '../widgets/sort_bar.dart';
import '../widgets/selection_action_bar.dart';
import '../widgets/goals_tracking_card.dart';
import '../providers/goals_provider.dart';
import '../providers/auto_refresh_provider.dart';
import '../../../../core/utils/debug_logger.dart';

// Note: Enums and providers moved to domain layer

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
  bool _isLoadingMore = false;
  // These fields are used for tracking filter changes
  // ignore: unused_field
  String? _lastIndustry;
  // ignore: unused_field
  String? _lastLocation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize search controller
    _searchController.addListener(() {
      setState(() {}); // Rebuild to update suffix icon visibility
    });
    
    // Initialize filters if needed
    if (widget.initialFilter == 'candidates') {
      Future.microtask(() async {
        final filterNotifier = ref.read(currentFilterStateProvider.notifier);
        await filterNotifier.updateCandidatesOnly(true);
      });
    }
    
    _loadLastScrapeContext();
    _initScrollController();
    
    // Initialize WebSocket connection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pageSpeedWebSocketProvider);
      // Load leads first, statistics will load via the ConversionPipeline widget
      ref.read(paginatedLeadsProvider.notifier).refreshLeads();
      // Delay goals refresh to avoid blocking
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          ref.read(goalsProvider.notifier).refreshMetrics();
        }
      });
    });
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
      DebugLogger.log('📱 UI: Scroll triggered load more');
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
    // Refresh goals metrics
    ref.read(goalsProvider.notifier).refreshMetrics();
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
    // Removed all filter listeners since we don't have filter UI anymore
    // Only keeping the search functionality through direct text field onChange
    
    // Single sort state listener - no race conditions!
    ref.listen(sortStateProvider, (previous, next) {
      if (previous != next) {
        DebugLogger.log('🔀 SORT CHANGED: ${previous?.option.name} (${previous?.ascending == true ? "asc" : "desc"}) -> ${next.option.name} (${next.ascending ? "asc" : "desc"})');
        DebugLogger.log('🔀 SORT FIELD: sortBy = ${next.sortField}, ascending = ${next.ascending}');
        
        // Only use search from the text field, no other filters
        final searchText = _searchController.text;
        
        ref.read(paginatedLeadsProvider.notifier).updateFilters(
          status: null,  // Always null - no status filter
          search: searchText.isEmpty ? null : searchText,
          candidatesOnly: false,
          calledToday: false,
          sortBy: next.sortField,
          sortAscending: next.ascending,
        );
      }
    });
    
    // Watch WebSocket state for new leads
    // Set up listener for WebSocket state changes
    ref.listen<PageSpeedWebSocketState>(pageSpeedWebSocketProvider, (previous, next) {
      final previousLeads = previous?.newLeads ?? {};
      final currentLeads = next.newLeads;
      final actuallyNewLeads = currentLeads.difference(previousLeads);
      
      if (actuallyNewLeads.isNotEmpty) {
        DebugLogger.log('🆕 New leads detected: $actuallyNewLeads');
        
        // Check if auto-refresh is enabled
        final autoRefresh = ref.read(autoRefreshLeadsProvider);
        
        if (autoRefresh) {
          DebugLogger.log('🔄 Auto-refresh enabled, refreshing leads...');
          Future.microtask(() {
            _refreshData();
          });
        } else {
          // Increment pending updates counter
          final currentPending = ref.read(pendingLeadsUpdateProvider);
          ref.read(pendingLeadsUpdateProvider.notifier).state = currentPending + actuallyNewLeads.length;
          DebugLogger.log('📦 Auto-refresh disabled, ${actuallyNewLeads.length} new leads pending (total: ${currentPending + actuallyNewLeads.length})');
        }
      }
    });
    
    // Use regular paginated provider without hidden status filtering
    final paginatedState = ref.watch(paginatedLeadsProvider);
    final pageSize = ref.watch(pageSizeProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              // Pipeline at the top - shows overall statistics
              const ConversionPipeline(),
              // Goals tracking card - shows daily call and monthly conversion goals
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GoalsTrackingCard(),
              ),
              // Active jobs monitor
              const ActiveJobsMonitor(),
              // Search bar only
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppTheme.elevatedSurface,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search leads...',
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppTheme.primaryGold,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.white.withValues(alpha: 0.3),
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              // Directly update without going through filter state
                              final sortState = ref.read(sortStateProvider);
                              ref.read(paginatedLeadsProvider.notifier).updateFilters(
                                status: null,  // Always null - no status filter
                                search: null,
                                candidatesOnly: false,
                                sortBy: sortState.sortField,
                                sortAscending: sortState.ascending,
                              );
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primaryGold),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                  onChanged: (value) {
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(Duration(milliseconds: 300), () {
                      if (mounted) {
                        // Directly update the paginated leads provider without going through filter state
                        final sortState = ref.read(sortStateProvider);
                        ref.read(paginatedLeadsProvider.notifier).updateFilters(
                          status: null,  // Always null - no status filter
                          search: value.isEmpty ? null : value,
                          candidatesOnly: false,
                          sortBy: sortState.sortField,
                          sortAscending: sortState.ascending,
                        );
                      }
                    });
                  },
                ),
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
                                Icon(Icons.error_outline),
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
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      padding: EdgeInsets.all(16),
      itemCount: leads.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == leads.length) {
          // Loading indicator at the bottom
          return const Padding(padding: EdgeInsets.all(16.0),
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
      duration: Duration(seconds: 5),
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
          margin: EdgeInsets.only(bottom: 8),
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
              child: Padding(padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Checkbox
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          ref.read(currentUIStateProvider.notifier).toggleLeadSelection(widget.lead.id);
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
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.mediumGray,
                            ),
                          ),
                          if (widget.lead.rating != null || widget.lead.reviewCount != null)
                            Padding(padding: EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  if (widget.lead.rating != null) ...[
                                    Icon(Icons.star, color: Colors.amber, size: 14),
                                    const SizedBox(width: 2),
                                    Text(
                                      widget.lead.rating!.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 12, color: AppTheme.mediumGray),
                                    ),
                                  ],
                                  if (widget.lead.reviewCount != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${widget.lead.reviewCount} reviews)',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.mediumGray),
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
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      return SizedBox.shrink();
    }
    
    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              SizedBox(
        width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(Icons.signal_wifi_off),
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