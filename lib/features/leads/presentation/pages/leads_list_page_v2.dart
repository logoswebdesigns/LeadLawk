import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/job_provider.dart';
import '../providers/server_status_provider.dart' hide dioProvider;
import '../widgets/loading_state.dart';
import '../widgets/empty_state.dart';

final leadsProvider = FutureProvider.autoDispose<List<Lead>>(
  (ref) async {
    print('🔄 leadsProvider: Fetching leads from repository...');
    final repository = ref.watch(leadsRepositoryProvider);
    
    // Get filter parameters from dedicated providers
    final status = ref.watch(statusFilterProvider);
    final locationFilter = ref.watch(locationFilterProvider);
    final industryFilter = ref.watch(industryFilterProvider);
    final sourceFilter = ref.watch(sourceFilterProvider);
    final search = ref.watch(searchFilterProvider);
    final candidatesOnly = ref.watch(candidatesOnlyProvider);
    final followUpFilter = ref.watch(followUpFilterProvider);
    final hasWebsiteFilter = ref.watch(hasWebsiteFilterProvider);
    final meetsRatingFilter = ref.watch(meetsRatingFilterProvider);
    final hasRecentReviewsFilter = ref.watch(hasRecentReviewsFilterProvider);
    final ratingRangeFilter = ref.watch(ratingRangeFilterProvider);
    final reviewCountRangeFilter = ref.watch(reviewCountRangeFilterProvider);
    final sortOption = ref.watch(sortOptionProvider);
    final sortAscending = ref.watch(sortAscendingProvider);
    
    final result = await repository.getLeads(
      status: status,
      search: null, // Use comprehensive client-side search instead
      candidatesOnly: candidatesOnly,
    );
    
    return result.fold(
      (failure) {
        print('❌ leadsProvider: Failed to fetch leads - ${failure.message}');
        throw Exception(failure.message);
      },
      (leads) {
        print('✅ leadsProvider: Successfully fetched ${leads.length} leads from repository');
        // Apply client-side comprehensive filtering
        var filteredLeads = List<Lead>.from(leads);
        
        // Apply field-specific filters
        if (locationFilter != null) {
          filteredLeads = filteredLeads.where((lead) => lead.location == locationFilter).toList();
        }
        
        if (industryFilter != null) {
          filteredLeads = filteredLeads.where((lead) => lead.industry == industryFilter).toList();
        }
        
        if (sourceFilter != null) {
          filteredLeads = filteredLeads.where((lead) => lead.source == sourceFilter).toList();
        }
        
        // Apply search filtering
        if (search.isNotEmpty) {
          final searchLower = search.toLowerCase();
          filteredLeads = filteredLeads.where((lead) {
            return lead.businessName.toLowerCase().contains(searchLower) ||
                   lead.phone.toLowerCase().contains(searchLower) ||
                   lead.location.toLowerCase().contains(searchLower) ||
                   lead.industry.toLowerCase().contains(searchLower) ||
                   (lead.websiteUrl?.toLowerCase().contains(searchLower) ?? false) ||
                   (lead.notes?.toLowerCase().contains(searchLower) ?? false) ||
                   lead.source.toLowerCase().contains(searchLower) ||
                   (lead.platformHint?.toLowerCase().contains(searchLower) ?? false);
          }).toList();
        }
        
        // Apply follow-up filtering
        if (followUpFilter != null) {
          final now = DateTime.now();
          filteredLeads = filteredLeads.where((lead) {
            if (followUpFilter == 'upcoming') {
              return lead.hasUpcomingFollowUp;
            } else if (followUpFilter == 'overdue') {
              return lead.hasOverdueFollowUp;
            }
            return true;
          }).toList();
        }
        
        // Apply property-based filtering
        if (hasWebsiteFilter != null) {
          filteredLeads = filteredLeads.where((lead) => lead.hasWebsite == hasWebsiteFilter).toList();
        }
        
        if (meetsRatingFilter != null) {
          filteredLeads = filteredLeads.where((lead) => lead.meetsRatingThreshold == meetsRatingFilter).toList();
        }
        
        if (hasRecentReviewsFilter != null) {
          filteredLeads = filteredLeads.where((lead) => lead.hasRecentReviews == hasRecentReviewsFilter).toList();
        }
        
        // Apply rating range filtering
        if (ratingRangeFilter != null) {
          filteredLeads = filteredLeads.where((lead) {
            final rating = lead.rating ?? 0;
            switch (ratingRangeFilter) {
              case '4+':
                return rating >= 4.0;
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
        
        // Apply review count range filtering
        if (reviewCountRangeFilter != null) {
          filteredLeads = filteredLeads.where((lead) {
            final reviewCount = lead.reviewCount ?? 0;
            switch (reviewCountRangeFilter) {
              case '50+':
                return reviewCount >= 50;
              case '20-50':
                return reviewCount >= 20 && reviewCount < 50;
              case '10-20':
                return reviewCount >= 10 && reviewCount < 20;
              case '5-10':
                return reviewCount >= 5 && reviewCount < 10;
              case '1-5':
                return reviewCount >= 1 && reviewCount < 5;
              default:
                return true;
            }
          }).toList();
        }
        
        // Apply sorting
        filteredLeads.sort((a, b) {
          int comparison = 0;
          switch (sortOption) {
            case SortOption.name:
              comparison = a.businessName.compareTo(b.businessName);
              break;
            case SortOption.rating:
              comparison = (b.rating ?? 0).compareTo(a.rating ?? 0);
              break;
            case SortOption.reviewCount:
              comparison = (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0);
              break;
            case SortOption.dateCreated:
              comparison = b.createdAt.compareTo(a.createdAt);
              break;
            case SortOption.newest:
              // Sort by creation date, newest first (always)
              comparison = b.createdAt.compareTo(a.createdAt);
              break;
            case SortOption.location:
              comparison = a.location.compareTo(b.location);
              break;
          }
          // For "newest" option, always sort newest first regardless of ascending flag
          if (sortOption == SortOption.newest) {
            return comparison; // b.compareTo(a) already gives newest first
          }
          return sortAscending ? comparison : -comparison;
        });
        return filteredLeads;
      },
    );
  },
);

// Provider to get all leads without filters for extracting unique values
final allLeadsProvider = FutureProvider.autoDispose<List<Lead>>(
  (ref) async {
    final repository = ref.watch(leadsRepositoryProvider);
    final result = await repository.getLeads(
      status: null,
      search: null,
      candidatesOnly: false,
    );
    
    return result.fold(
      (failure) => <Lead>[],
      (leads) => leads,
    );
  },
);

// Provider for unique field values for filters
final uniqueFieldValuesProvider = Provider.autoDispose<Map<String, List<String>>>((ref) {
  final allLeadsAsync = ref.watch(allLeadsProvider);
  
  return allLeadsAsync.maybeWhen(
    data: (leads) {
      final locations = leads.map((l) => l.location).toSet().toList()..sort();
      final industries = leads.map((l) => l.industry).toSet().toList()..sort();
      final sources = leads.map((l) => l.source).toSet().toList()..sort();
      
      return {
        'locations': locations,
        'industries': industries,
        'sources': sources,
      };
    },
    orElse: () => {
      'locations': <String>[],
      'industries': <String>[],
      'sources': <String>[],
    },
  );
});

// Dedicated providers for filters to prevent unnecessary rebuilds
final statusFilterProvider = StateProvider<String?>((ref) => null);
final locationFilterProvider = StateProvider<String?>((ref) => null);
final industryFilterProvider = StateProvider<String?>((ref) => null);
final sourceFilterProvider = StateProvider<String?>((ref) => null);
final searchFilterProvider = StateProvider<String>((ref) => '');
final candidatesOnlyProvider = StateProvider<bool>((ref) => false);
final followUpFilterProvider = StateProvider<String?>((ref) => null); // 'upcoming', 'overdue', null

// Property filter providers
final hasWebsiteFilterProvider = StateProvider<bool?>((ref) => null); // null = any, true = has website, false = no website
final meetsRatingFilterProvider = StateProvider<bool?>((ref) => null); // null = any, true = meets threshold, false = doesn't meet
final hasRecentReviewsFilterProvider = StateProvider<bool?>((ref) => null); // null = any, true = has recent, false = no recent
final ratingRangeFilterProvider = StateProvider<String?>((ref) => null); // '4+', '3-4', '2-3', '1-2'
final reviewCountRangeFilterProvider = StateProvider<String?>((ref) => null); // '50+', '20-50', '10-20', '5-10', '1-5'

// Sort and bulk action providers
enum SortOption { name, rating, reviewCount, dateCreated, newest, location }
final sortOptionProvider = StateProvider<SortOption>((ref) => SortOption.dateCreated);
final sortAscendingProvider = StateProvider<bool>((ref) => false); // Default newest first
final selectedLeadsProvider = StateProvider<Set<String>>((ref) => <String>{});


class LeadsListPageV2 extends ConsumerStatefulWidget {
  final String? initialFilter;

  const LeadsListPageV2({super.key, this.initialFilter});

  @override
  ConsumerState<LeadsListPageV2> createState() => _LeadsListPageV2State();
}

class _LeadsListPageV2State extends ConsumerState<LeadsListPageV2> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String? _lastIndustry;
  String? _lastLocation;
  final List<String> _loadingLogs = [];
  Timer? _debounceTimer;
  bool _isPipelineExpanded = true;

  @override
  void initState() {
    super.initState();
    
    _initScrollController();
    
    if (widget.initialFilter == 'candidates') {
      Future.microtask(() {
        ref.read(candidatesOnlyProvider.notifier).state = true;
      });
    }
    _loadLastScrapeContext();
    _addLoadingLog('Initializing LeadLoq...');
    
    // Set up search debouncing
    _searchController.addListener(_onSearchChanged);
    
    // Invalidate cache on page initialization to ensure fresh filter data
    Future.microtask(() {
      ref.invalidate(allLeadsProvider);
      ref.invalidate(uniqueFieldValuesProvider);
    });
  }

  void _initScrollController() async {
    // Load saved scroll position from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedPosition = prefs.getDouble('leads_list_scroll_position') ?? 0.0;
    
    // Set the initial scroll position after the widget is built
    if (savedPosition > 0 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && mounted) {
          _scrollController.jumpTo(savedPosition);
        }
      });
    }
  }

  void _addLoadingLog(String log) {
    if (mounted) {
      setState(() {
        _loadingLogs.add(log);
        if (_loadingLogs.length > 5) {
          _loadingLogs.removeAt(0);
        }
      });
    }
  }

  Future<void> _loadLastScrapeContext() async {
    _addLoadingLog('Loading user preferences...');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastIndustry = prefs.getString('last_industry');
      _lastLocation = prefs.getString('last_location');
    });
    _addLoadingLog('Preferences loaded successfully');
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(searchFilterProvider.notifier).state = _searchController.text;
      }
    });
  }

  void _storeScrollPosition() async {
    if (_scrollController.hasClients && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('leads_list_scroll_position', _scrollController.position.pixels);
    }
  }



  void _showJobsSheet(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsListProvider);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.analytics, color: AppTheme.primaryGold),
                  const SizedBox(width: 12),
                  const Text(
                    'Active Jobs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/server');
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(color: AppTheme.primaryGold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.elevatedSurface),
            Expanded(
              child: jobsAsync.when(
                data: (jobs) {
                  final runningJobs = jobs.where((job) => job['status'] == 'running').toList();
                  if (runningJobs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No active jobs',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: runningJobs.length,
                    itemBuilder: (context, index) {
                      final job = runningJobs[index];
                      final jobId = job['job_id']?.toString() ?? '';
                      final processed = job['processed'] ?? 0;
                      final total = job['total'] ?? 0;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.elevatedSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    jobId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: total == 0 ? 0 : (processed / total).toDouble(),
                              backgroundColor: AppTheme.backgroundDark,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Progress: $processed / $total',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                  child: Text(
                    'Failed to load jobs',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _hasActiveFilters(String? statusFilter, String? locationFilter, String? industryFilter, String? sourceFilter, bool candidatesOnly, String? followUpFilter, bool? hasWebsiteFilter, bool? meetsRatingFilter, bool? hasRecentReviewsFilter, String? ratingRangeFilter, String? reviewCountRangeFilter) {
    return statusFilter != null || locationFilter != null || industryFilter != null || sourceFilter != null || candidatesOnly || followUpFilter != null || hasWebsiteFilter != null || meetsRatingFilter != null || hasRecentReviewsFilter != null || ratingRangeFilter != null || reviewCountRangeFilter != null;
  }

  int _getActiveFilterCount(String? statusFilter, String? locationFilter, String? industryFilter, String? sourceFilter, bool candidatesOnly, String? followUpFilter, bool? hasWebsiteFilter, bool? meetsRatingFilter, bool? hasRecentReviewsFilter, String? ratingRangeFilter, String? reviewCountRangeFilter) {
    int count = 0;
    if (statusFilter != null) count++;
    if (locationFilter != null) count++;
    if (industryFilter != null) count++;
    if (sourceFilter != null) count++;
    if (candidatesOnly) count++;
    if (followUpFilter != null) count++;
    if (hasWebsiteFilter != null) count++;
    if (meetsRatingFilter != null) count++;
    if (hasRecentReviewsFilter != null) count++;
    if (ratingRangeFilter != null) count++;
    if (reviewCountRangeFilter != null) count++;
    return count;
  }

  Widget _buildActiveFilterSummary(String? statusFilter, String? locationFilter, String? industryFilter, String? sourceFilter, bool candidatesOnly, String? followUpFilter, bool? hasWebsiteFilter, bool? meetsRatingFilter, bool? hasRecentReviewsFilter, String? ratingRangeFilter, String? reviewCountRangeFilter) {
    final pills = <Widget>[];
    
    if (statusFilter != null) {
      // Find the status enum to get proper display name
      final status = LeadStatus.values.firstWhere(
        (s) => _getStatusLabel(s).toLowerCase() == statusFilter,
        orElse: () => LeadStatus.new_,
      );
      pills.add(_buildFilterPill(
        label: _getStatusLabel(status),
        icon: _getStatusIcon(status),
        color: _getStatusColor(status),
        onRemove: () => ref.read(statusFilterProvider.notifier).state = null,
      ));
    }
    
    if (candidatesOnly) {
      pills.add(_buildFilterPill(
        label: 'Candidates Only',
        icon: Icons.star,
        color: AppTheme.primaryGold,
        onRemove: () => ref.read(candidatesOnlyProvider.notifier).state = false,
      ));
    }
    
    if (locationFilter != null) {
      pills.add(_buildFilterPill(
        label: locationFilter,
        icon: Icons.location_on,
        color: AppTheme.primaryBlue,
        onRemove: () => ref.read(locationFilterProvider.notifier).state = null,
      ));
    }
    
    if (industryFilter != null) {
      pills.add(_buildFilterPill(
        label: industryFilter,
        icon: Icons.business,
        color: AppTheme.primaryIndigo,
        onRemove: () => ref.read(industryFilterProvider.notifier).state = null,
      ));
    }
    
    if (sourceFilter != null) {
      pills.add(_buildFilterPill(
        label: sourceFilter,
        icon: Icons.source,
        color: AppTheme.accentPurple,
        onRemove: () => ref.read(sourceFilterProvider.notifier).state = null,
      ));
    }
    
    if (followUpFilter != null) {
      pills.add(_buildFilterPill(
        label: followUpFilter == 'upcoming' ? 'Upcoming Follow-ups' : 'Overdue Follow-ups',
        icon: followUpFilter == 'upcoming' ? Icons.schedule : Icons.warning,
        color: followUpFilter == 'upcoming' ? AppTheme.primaryBlue : AppTheme.warningOrange,
        onRemove: () => ref.read(followUpFilterProvider.notifier).state = null,
      ));
    }
    
    // Property filters
    if (hasWebsiteFilter != null) {
      pills.add(_buildFilterPill(
        label: hasWebsiteFilter! ? 'Has Website' : 'No Website',
        icon: hasWebsiteFilter! ? Icons.language : Icons.language_outlined,
        color: hasWebsiteFilter! ? AppTheme.accentCyan : Colors.grey,
        onRemove: () => ref.read(hasWebsiteFilterProvider.notifier).state = null,
      ));
    }
    
    if (meetsRatingFilter != null) {
      pills.add(_buildFilterPill(
        label: 'Quality Rating',
        icon: Icons.verified,
        color: AppTheme.successGreen,
        onRemove: () => ref.read(meetsRatingFilterProvider.notifier).state = null,
      ));
    }
    
    if (hasRecentReviewsFilter != null) {
      pills.add(_buildFilterPill(
        label: 'Recent Reviews',
        icon: Icons.schedule,
        color: AppTheme.primaryIndigo,
        onRemove: () => ref.read(hasRecentReviewsFilterProvider.notifier).state = null,
      ));
    }
    
    if (ratingRangeFilter != null) {
      pills.add(_buildFilterPill(
        label: '$ratingRangeFilter Stars',
        icon: Icons.star,
        color: AppTheme.warningOrange,
        onRemove: () => ref.read(ratingRangeFilterProvider.notifier).state = null,
      ));
    }
    
    if (reviewCountRangeFilter != null) {
      pills.add(_buildFilterPill(
        label: '$reviewCountRangeFilter Reviews',
        icon: Icons.reviews,
        color: AppTheme.accentPurple,
        onRemove: () => ref.read(reviewCountRangeFilterProvider.notifier).state = null,
      ));
    }
    
    if (pills.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_list,
                size: 16,
                color: AppTheme.primaryGold,
              ),
              const SizedBox(width: 8),
              Text(
                'Active Filters',
                style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ' (${pills.length})',
                style: TextStyle(
                  color: AppTheme.mediumGray,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  // Clear all filters
                  ref.read(statusFilterProvider.notifier).state = null;
                  ref.read(locationFilterProvider.notifier).state = null;
                  ref.read(industryFilterProvider.notifier).state = null;
                  ref.read(sourceFilterProvider.notifier).state = null;
                  ref.read(candidatesOnlyProvider.notifier).state = false;
                  ref.read(followUpFilterProvider.notifier).state = null;
                },
                icon: const Icon(Icons.clear_all, size: 14),
                label: const Text(
                  'Clear All',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.mediumGray,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pills,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onRemove,
  }) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: color.withOpacity(0.9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  void _showFilterModal(BuildContext context, Map<String, List<String>> uniqueValues, String? locationFilter, String? industryFilter, String? sourceFilter) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _FilterModal(
        uniqueValues: uniqueValues,
        currentLocationFilter: locationFilter,
        currentIndustryFilter: industryFilter,
        currentSourceFilter: sourceFilter,
        onFiltersChanged: (location, industry, source) {
          ref.read(locationFilterProvider.notifier).state = location;
          ref.read(industryFilterProvider.notifier).state = industry;
          ref.read(sourceFilterProvider.notifier).state = source;
        },
      ),
    );
  }

  Future<void> _searchGoogle(Lead lead) async {
    // Extract city from location (assumes format like "Austin, Texas" or "Austin")
    final locationParts = lead.location.split(',');
    final city = locationParts.first.trim();
    
    final query = '${lead.businessName} $city';
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse('https://www.google.com/search?q=$encodedQuery');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback - this shouldn't happen but good to have
      print('Could not launch $url');
    }
  }

  Color _getStatusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return AppTheme.mediumGray;
      case LeadStatus.viewed:
        return Colors.blueGrey;
      case LeadStatus.called:
        return AppTheme.warningOrange;
      case LeadStatus.interested:
        return AppTheme.primaryBlue;
      case LeadStatus.converted:
        return AppTheme.successGreen;
      case LeadStatus.dnc:
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
      case LeadStatus.dnc:
        return 'DNC';
    }
  }

  IconData _getStatusIcon(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return Icons.fiber_new;
      case LeadStatus.viewed:
        return Icons.visibility;
      case LeadStatus.called:
        return Icons.phone_in_talk;
      case LeadStatus.interested:
        return Icons.star;
      case LeadStatus.converted:
        return Icons.check_circle;
      case LeadStatus.dnc:
        return Icons.block;
    }
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.name:
        return 'Name';
      case SortOption.rating:
        return 'Rating';
      case SortOption.reviewCount:
        return 'Reviews';
      case SortOption.dateCreated:
        return 'Date';
      case SortOption.newest:
        return 'Newest';
      case SortOption.location:
        return 'Location';
    }
  }

  Future<void> _markLeadAsViewed(String leadId) async {
    try {
      final repository = ref.read(leadsRepositoryProvider);
      
      // Get the current lead first
      final leadResult = await repository.getLead(leadId);
      leadResult.fold(
        (failure) => print('Error getting lead: ${failure.message}'),
        (lead) async {
          // Update the lead status from NEW to VIEWED
          final updatedLead = lead.copyWith(status: LeadStatus.viewed);
          final updateResult = await repository.updateLead(updatedLead);
          
          updateResult.fold(
            (failure) => print('Error updating lead: ${failure.message}'),
            (_) {
              // Refresh the leads list to reflect the status change
              ref.invalidate(leadsProvider);
            },
          );
        },
      );
    } catch (e) {
      print('Error marking lead as viewed: $e');
    }
  }

  Future<void> _bulkDeleteLeads(Set<String> selectedIds) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Leads'),
        content: Text('Are you sure you want to delete ${selectedIds.length} selected leads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    // Simple approach - show loading, do work, then hide loading
    final loadingOverlay = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Delete each lead individually (since we don't have a bulk delete endpoint)
      final dio = ref.read(dioProvider);
      int deletedCount = 0;
      
      for (final leadId in selectedIds) {
        try {
          await dio.delete('http://localhost:8000/leads/$leadId');
          deletedCount++;
        } catch (e) {
          // Continue with other deletions even if one fails
          print('Failed to delete lead $leadId: $e');
        }
      }
      
      // Dismiss loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      if (mounted) {
        // Show result
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted $deletedCount of ${selectedIds.length} leads'),
            backgroundColor: deletedCount == selectedIds.length 
                ? Colors.green 
                : Colors.orange,
          ),
        );
        
        // Clear selection and refresh all lead data
        ref.read(selectedLeadsProvider.notifier).state = <String>{};
        ref.invalidate(leadsProvider);
        ref.invalidate(allLeadsProvider);
        ref.invalidate(uniqueFieldValuesProvider);
      }
    } catch (e) {
      // Dismiss loading dialog on error
      Navigator.of(context, rootNavigator: true).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting leads: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadsProvider);
    final serverState = ref.watch(serverStatusProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final locationFilter = ref.watch(locationFilterProvider);
    final industryFilter = ref.watch(industryFilterProvider);
    final sourceFilter = ref.watch(sourceFilterProvider);
    final candidatesOnly = ref.watch(candidatesOnlyProvider);
    final followUpFilter = ref.watch(followUpFilterProvider);
    final hasWebsiteFilter = ref.watch(hasWebsiteFilterProvider);
    final meetsRatingFilter = ref.watch(meetsRatingFilterProvider);
    final hasRecentReviewsFilter = ref.watch(hasRecentReviewsFilterProvider);
    final ratingRangeFilter = ref.watch(ratingRangeFilterProvider);
    final reviewCountRangeFilter = ref.watch(reviewCountRangeFilterProvider);
    final selectedLeads = ref.watch(selectedLeadsProvider);
    final sortOption = ref.watch(sortOptionProvider);
    final sortAscending = ref.watch(sortAscendingProvider);
    final uniqueValues = ref.watch(uniqueFieldValuesProvider);

    // Add server status to logs
    if (serverState.status == ServerStatus.checking) {
      _addLoadingLog('Checking server connection...');
    } else if (serverState.status == ServerStatus.online) {
      _addLoadingLog('Server connected successfully');
    } else if (serverState.status == ServerStatus.starting) {
      _addLoadingLog('Starting server...');
    }


    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate all providers to refresh data
          ref.invalidate(leadsProvider);
          ref.invalidate(allLeadsProvider);
          ref.invalidate(uniqueFieldValuesProvider);
          ref.invalidate(jobsListProvider);
          ref.read(serverStatusProvider.notifier).checkServerHealth();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: AppTheme.primaryGold,
        backgroundColor: AppTheme.backgroundDark,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
          // Collapsible metrics dashboard with safe area
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false, // Only protect from top interference
              child: Container(
                margin: const EdgeInsets.only(top: 8), // Additional margin for better spacing
                child: Consumer(
              builder: (context, ref, child) {
                final allLeadsAsync = ref.watch(allLeadsProvider);
                
                return allLeadsAsync.maybeWhen(
                  data: (allLeads) {
                    // Use all leads for pipeline metrics, not just filtered results
                    final totalLeads = allLeads.length;
                    final newLeads = allLeads.where((l) => l.status == LeadStatus.new_).length;
                    final viewedLeads = allLeads.where((l) => l.status == LeadStatus.viewed).length;
                    final calledLeads = allLeads.where((l) => l.status == LeadStatus.called).length;
                    final interestedLeads = allLeads.where((l) => l.status == LeadStatus.interested).length;
                    final convertedLeads = allLeads.where((l) => l.status == LeadStatus.converted).length;
                
                final dncLeads = allLeads.where((l) => l.status == LeadStatus.dnc).length;
                final contactedLeads = calledLeads + interestedLeads + convertedLeads + dncLeads;
                final workedLeads = viewedLeads + calledLeads + interestedLeads + convertedLeads + dncLeads;
                final conversionRate = workedLeads > 0 
                    ? ((convertedLeads / workedLeads) * 100).toStringAsFixed(1)
                    : '0.0';
                final contactRate = totalLeads > 0 
                    ? ((contactedLeads / totalLeads) * 100).toStringAsFixed(1)
                    : '0.0';
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryGold.withOpacity(0.1),
                        AppTheme.primaryBlue.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryGold.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Collapsible header
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            setState(() {
                              _isPipelineExpanded = !_isPipelineExpanded;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGold.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.trending_up,
                                    color: AppTheme.primaryGold,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Your Lead Pipeline',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Track your success metrics',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$totalLeads Total',
                                    style: const TextStyle(
                                      color: AppTheme.successGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedRotation(
                                  duration: const Duration(milliseconds: 200),
                                  turns: _isPipelineExpanded ? 0.5 : 0.0,
                                  child: const Icon(
                                    Icons.expand_more,
                                    color: AppTheme.primaryGold,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Collapsible content
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                        height: _isPipelineExpanded ? null : 0,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _isPipelineExpanded ? 1.0 : 0.0,
                          child: _isPipelineExpanded ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Column(
                              children: [
                                // Key metrics row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricCard(
                                        title: 'Conversion Rate',
                                        value: '$conversionRate%',
                                        subtitle: '$convertedLeads customers',
                                        icon: Icons.star,
                                        color: AppTheme.successGreen,
                                        trend: convertedLeads > 0 ? 'up' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildMetricCard(
                                        title: 'Contact Rate',
                                        value: '$contactRate%',
                                        subtitle: '$contactedLeads contacted',
                                        icon: Icons.phone,
                                        color: AppTheme.primaryBlue,
                                        trend: contactedLeads > 0 ? 'up' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildMetricCard(
                                        title: 'Hot Leads',
                                        value: '$interestedLeads',
                                        subtitle: 'interested prospects',
                                        icon: Icons.local_fire_department,
                                        color: AppTheme.warningOrange,
                                        trend: interestedLeads > 0 ? 'hot' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Progress pipeline
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.backgroundDark.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.arrow_forward,
                                            color: AppTheme.mediumGray,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Pipeline Progress',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Spacer(),
                                          Expanded(
                                            child: Text(
                                              'Next: Contact ${newLeads + viewedLeads} leads',
                                              style: TextStyle(
                                                color: AppTheme.primaryGold,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.end,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          _buildPipelineStep('New', newLeads, AppTheme.mediumGray, onTap: () {
                                            ref.read(statusFilterProvider.notifier).state = _mapPipelineLabelToStatus('New');
                                          }),
                                          _buildPipelineArrow(),
                                          _buildPipelineStep('Viewed', viewedLeads, Colors.blueGrey, onTap: () {
                                            ref.read(statusFilterProvider.notifier).state = _mapPipelineLabelToStatus('Viewed');
                                          }),
                                          _buildPipelineArrow(),
                                          _buildPipelineStep('Called', calledLeads, AppTheme.warningOrange, onTap: () {
                                            ref.read(statusFilterProvider.notifier).state = _mapPipelineLabelToStatus('Called');
                                          }),
                                          _buildPipelineArrow(),
                                          _buildPipelineStep('Hot', interestedLeads, AppTheme.primaryBlue, onTap: () {
                                            ref.read(statusFilterProvider.notifier).state = _mapPipelineLabelToStatus('Hot');
                                          }),
                                          _buildPipelineArrow(),
                                          _buildPipelineStep('Won', convertedLeads, AppTheme.successGreen, onTap: () {
                                            ref.read(statusFilterProvider.notifier).state = _mapPipelineLabelToStatus('Won');
                                          }),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ) : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                );
                  },
                  orElse: () => const SizedBox.shrink(),
                );
              },
                ),
              ),
            ),
          ),
          // Apple-style filtering and search section
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.backgroundDark,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar - Apple style, prominent and always visible
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Search leads...',
                        hintStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        prefixIcon: Icon(
                          CupertinoIcons.search,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Status filter chips - Apple style horizontal scrollable
                  if (LeadStatus.values.isNotEmpty) ...[
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // Search filter chip (if search is active)
                          if (ref.watch(searchFilterProvider).isNotEmpty) ...[
                            _buildFilterChip(
                              label: 'Search: "${ref.watch(searchFilterProvider)}"',
                              icon: CupertinoIcons.search,
                              isSelected: true,
                              onSelected: (selected) {
                                if (!selected) {
                                  _searchController.clear();
                                  ref.read(searchFilterProvider.notifier).state = '';
                                }
                              },
                              color: AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Candidates filter
                          _buildFilterChip(
                            label: 'Candidates',
                            icon: Icons.star,
                            isSelected: candidatesOnly,
                            onSelected: (selected) {
                              ref.read(candidatesOnlyProvider.notifier).state = selected;
                            },
                            color: AppTheme.primaryGold,
                          ),
                          const SizedBox(width: 8),
                          // Status filters
                          ...LeadStatus.values.map((status) {
                            final isSelected = statusFilter == 
                                _getStatusLabel(status).toLowerCase();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildFilterChip(
                                label: _getStatusLabel(status),
                                icon: _getStatusIcon(status),
                                isSelected: isSelected,
                                onSelected: (selected) {
                                  ref.read(statusFilterProvider.notifier).state = selected
                                      ? _getStatusLabel(status).toLowerCase()
                                      : null;
                                },
                                color: _getStatusColor(status),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Follow-up filter chips
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip(
                          label: 'Upcoming Follow-ups',
                          icon: Icons.schedule,
                          isSelected: ref.watch(followUpFilterProvider) == 'upcoming',
                          onSelected: (selected) {
                            ref.read(followUpFilterProvider.notifier).state = selected ? 'upcoming' : null;
                          },
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Overdue Follow-ups',
                          icon: Icons.warning,
                          isSelected: ref.watch(followUpFilterProvider) == 'overdue',
                          onSelected: (selected) {
                            ref.read(followUpFilterProvider.notifier).state = selected ? 'overdue' : null;
                          },
                          color: AppTheme.warningOrange,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Property filter chips
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip(
                          label: 'Has Website',
                          icon: Icons.language,
                          isSelected: ref.watch(hasWebsiteFilterProvider) == true,
                          onSelected: (selected) {
                            ref.read(hasWebsiteFilterProvider.notifier).state = selected ? true : null;
                          },
                          color: AppTheme.accentCyan,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'No Website',
                          icon: Icons.language_outlined,
                          isSelected: ref.watch(hasWebsiteFilterProvider) == false,
                          onSelected: (selected) {
                            ref.read(hasWebsiteFilterProvider.notifier).state = selected ? false : null;
                          },
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Quality Rating',
                          icon: Icons.verified,
                          isSelected: ref.watch(meetsRatingFilterProvider) == true,
                          onSelected: (selected) {
                            ref.read(meetsRatingFilterProvider.notifier).state = selected ? true : null;
                          },
                          color: AppTheme.successGreen,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Recent Reviews',
                          icon: Icons.schedule,
                          isSelected: ref.watch(hasRecentReviewsFilterProvider) == true,
                          onSelected: (selected) {
                            ref.read(hasRecentReviewsFilterProvider.notifier).state = selected ? true : null;
                          },
                          color: AppTheme.primaryIndigo,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: '4+ Stars',
                          icon: Icons.star,
                          isSelected: ref.watch(ratingRangeFilterProvider) == '4+',
                          onSelected: (selected) {
                            ref.read(ratingRangeFilterProvider.notifier).state = selected ? '4+' : null;
                          },
                          color: AppTheme.warningOrange,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: '50+ Reviews',
                          icon: Icons.reviews,
                          isSelected: ref.watch(reviewCountRangeFilterProvider) == '50+',
                          onSelected: (selected) {
                            ref.read(reviewCountRangeFilterProvider.notifier).state = selected ? '50+' : null;
                          },
                          color: AppTheme.accentPurple,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Action bar - More Filters only
                  Row(
                    children: [
                      
                      // More Filters button
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: _hasActiveFilters(statusFilter, locationFilter, industryFilter, sourceFilter, candidatesOnly, followUpFilter, hasWebsiteFilter, meetsRatingFilter, hasRecentReviewsFilter, ratingRangeFilter, reviewCountRangeFilter) 
                              ? AppTheme.primaryGold.withOpacity(0.15) 
                              : AppTheme.elevatedSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _hasActiveFilters(statusFilter, locationFilter, industryFilter, sourceFilter, candidatesOnly, followUpFilter, hasWebsiteFilter, meetsRatingFilter, hasRecentReviewsFilter, ratingRangeFilter, reviewCountRangeFilter)
                                ? AppTheme.primaryGold.withOpacity(0.4)
                                : Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _showFilterModal(context, uniqueValues, locationFilter, industryFilter, sourceFilter),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tune,
                                    size: 16,
                                    color: _hasActiveFilters(statusFilter, locationFilter, industryFilter, sourceFilter, candidatesOnly, followUpFilter, hasWebsiteFilter, meetsRatingFilter, hasRecentReviewsFilter, ratingRangeFilter, reviewCountRangeFilter)
                                        ? AppTheme.primaryGold
                                        : AppTheme.mediumGray,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'More',
                                    style: TextStyle(
                                      color: _hasActiveFilters(statusFilter, locationFilter, industryFilter, sourceFilter, candidatesOnly, followUpFilter, hasWebsiteFilter, meetsRatingFilter, hasRecentReviewsFilter, ratingRangeFilter, reviewCountRangeFilter)
                                          ? AppTheme.primaryGold
                                          : Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (_getActiveFilterCount(statusFilter, locationFilter, industryFilter, sourceFilter, candidatesOnly, followUpFilter, hasWebsiteFilter, meetsRatingFilter, hasRecentReviewsFilter, ratingRangeFilter, reviewCountRangeFilter) > (statusFilter != null ? 1 : 0) + (candidatesOnly ? 1 : 0) + (followUpFilter != null ? 1 : 0) + (hasWebsiteFilter != null ? 1 : 0) + (meetsRatingFilter != null ? 1 : 0) + (hasRecentReviewsFilter != null ? 1 : 0) + (ratingRangeFilter != null ? 1 : 0) + (reviewCountRangeFilter != null ? 1 : 0)) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGold,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${_getActiveFilterCount(statusFilter, locationFilter, industryFilter, sourceFilter, candidatesOnly, followUpFilter, hasWebsiteFilter, meetsRatingFilter, hasRecentReviewsFilter, ratingRangeFilter, reviewCountRangeFilter) - (statusFilter != null ? 1 : 0) - (candidatesOnly ? 1 : 0) - (followUpFilter != null ? 1 : 0) - (hasWebsiteFilter != null ? 1 : 0) - (meetsRatingFilter != null ? 1 : 0) - (hasRecentReviewsFilter != null ? 1 : 0) - (ratingRangeFilter != null ? 1 : 0) - (reviewCountRangeFilter != null ? 1 : 0)}',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      
                      // Refresh button
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.elevatedSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              // Refresh all data
                              ref.invalidate(leadsProvider);
                              ref.invalidate(allLeadsProvider);
                              ref.invalidate(uniqueFieldValuesProvider);
                              ref.invalidate(jobsListProvider);
                              ref.read(serverStatusProvider.notifier).checkServerHealth();
                              
                              // Show feedback
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Leads refreshed'),
                                  duration: Duration(milliseconds: 1500),
                                  backgroundColor: AppTheme.successGreen,
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Clear all filters button - only show when filters are active
                      if (_hasActiveFilters(statusFilter, locationFilter, industryFilter, sourceFilter, candidatesOnly, followUpFilter, hasWebsiteFilter, meetsRatingFilter, hasRecentReviewsFilter, ratingRangeFilter, reviewCountRangeFilter))
                        TextButton.icon(
                          onPressed: () {
                            ref.read(statusFilterProvider.notifier).state = null;
                            ref.read(locationFilterProvider.notifier).state = null;
                            ref.read(industryFilterProvider.notifier).state = null;
                            ref.read(sourceFilterProvider.notifier).state = null;
                            ref.read(candidatesOnlyProvider.notifier).state = false;
                            ref.read(followUpFilterProvider.notifier).state = null;
                            ref.read(hasWebsiteFilterProvider.notifier).state = null;
                            ref.read(meetsRatingFilterProvider.notifier).state = null;
                            ref.read(hasRecentReviewsFilterProvider.notifier).state = null;
                            ref.read(ratingRangeFilterProvider.notifier).state = null;
                            ref.read(reviewCountRangeFilterProvider.notifier).state = null;
                          },
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Clear'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.mediumGray,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  
                  // Active filter summary - only show when advanced filters are applied
                  const SizedBox(height: 8),
                  _buildActiveFilterSummary(statusFilter, locationFilter, industryFilter, sourceFilter, candidatesOnly, followUpFilter, hasWebsiteFilter, meetsRatingFilter, hasRecentReviewsFilter, ratingRangeFilter, reviewCountRangeFilter),
                ],
              ),
            ),
          ),
        
        // Select All row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                const SizedBox(height: 12),
                leadsAsync.maybeWhen(
                    data: (leads) {
                      if (leads.isEmpty) return const SizedBox.shrink();
                      
                      final allSelected = leads.every((lead) => selectedLeads.contains(lead.id));
                      final someSelected = selectedLeads.isNotEmpty;
                      
                      return Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: allSelected ? AppTheme.primaryGold : 
                                     someSelected ? AppTheme.primaryGold.withOpacity(0.5) : Colors.transparent,
                              border: Border.all(
                                color: someSelected ? AppTheme.primaryGold : AppTheme.mediumGray,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                if (allSelected) {
                                  // Deselect all
                                  ref.read(selectedLeadsProvider.notifier).state = <String>{};
                                } else {
                                  // Select all visible leads
                                  final allIds = leads.map((lead) => lead.id).toSet();
                                  ref.read(selectedLeadsProvider.notifier).state = allIds;
                                }
                              },
                              child: Icon(
                                allSelected ? Icons.check : 
                                someSelected ? Icons.remove : null,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            allSelected ? 'Deselect All' :
                            someSelected ? 'Select All' : 'Select All',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          
                          // Sort controls
                          if (!someSelected) ...[
                            // Sort dropdown - compact style
                            Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.elevatedSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<SortOption>(
                                  value: sortOption,
                                  dropdownColor: AppTheme.elevatedSurface,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: AppTheme.primaryGold,
                                    size: 16,
                                  ),
                                  onChanged: (value) {
                                    if (value != null) {
                                      ref.read(sortOptionProvider.notifier).state = value;
                                    }
                                  },
                                  items: SortOption.values.map((option) {
                                    return DropdownMenuItem(
                                      value: option,
                                      child: Text(_getSortLabel(option)),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            
                            // Sort direction button - compact
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.elevatedSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  ref.read(sortAscendingProvider.notifier).state = !sortAscending;
                                },
                                icon: Icon(
                                  sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                  color: AppTheme.primaryGold,
                                  size: 16,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          
                          if (someSelected)
                            Text(
                              '${selectedLeads.length} of ${leads.length}',
                              style: const TextStyle(
                                color: AppTheme.primaryGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                  
                  // Bulk actions bar (shown when items are selected)
                  if (selectedLeads.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryGold.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppTheme.primaryGold, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Bulk Actions',
                            style: TextStyle(
                              color: AppTheme.primaryGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              ref.read(selectedLeadsProvider.notifier).state = <String>{};
                            },
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Clear'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _bulkDeleteLeads(selectedLeads),
                            icon: const Icon(Icons.delete, size: 16),
                            label: const Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        
        // Leads content
        leadsAsync.when(
            data: (leads) {
              if (leads.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.inbox,
                    title: 'No leads found',
                    description: candidatesOnly
                        ? 'No candidates match your criteria. Try adjusting your filters or generate new leads.'
                        : 'Generate new leads to find potential customers in your area.',
                    buttonText: 'Find New Leads',
                    onButtonPressed: () => context.go('/browser'),
                  ),
                );
              }
              
              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final lead = leads[index];
                      return _buildLeadCard(context, lead);
                    },
                    childCount: leads.length,
                  ),
                ),
              );
            },
            loading: () {
              _addLoadingLog('Fetching leads from server...');
              return SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingState(
                  message: 'Loading your leads',
                  submessage: 'Please wait while we fetch your data',
                  logs: _loadingLogs,
                ),
              );
            },
            error: (error, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.error_outline,
                title: 'Connection Error',
                description: 'Unable to load leads. Please check your server connection and try again.',
                buttonText: 'Retry',
                onButtonPressed: () {
                  ref.invalidate(leadsProvider);
                },
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildServerStatusBadge(ServerState serverState) {
    Color statusColor;
    IconData statusIcon;
    
    switch (serverState.status) {
      case ServerStatus.online:
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.check_circle;
        break;
      case ServerStatus.offline:
      case ServerStatus.error:
        statusColor = AppTheme.errorRed;
        statusIcon = Icons.error;
        break;
      case ServerStatus.checking:
      case ServerStatus.starting:
        statusColor = AppTheme.warningOrange;
        statusIcon = Icons.sync;
        break;
    }
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/server'),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                statusIcon,
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Server',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicFilterDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> options,
    required Function(String?) onChanged,
    required Color color,
  }) {
    if (options.isEmpty) return const SizedBox.shrink();
    
    return Container(
      height: 40,
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: value != null ? color.withOpacity(0.1) : AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value != null ? color.withOpacity(0.3) : AppTheme.elevatedSurface,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppTheme.mediumGray),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.mediumGray,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          dropdownColor: AppTheme.elevatedSurface,
          style: TextStyle(color: value != null ? color : Colors.white, fontSize: 13),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: value != null ? color : AppTheme.mediumGray,
            size: 16,
          ),
          isExpanded: true,
          onChanged: onChanged,
          selectedItemBuilder: (context) {
            return [null, ...options].map((option) {
              if (option == null) return Container();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }).toList();
          },
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  const Icon(Icons.clear, size: 14, color: AppTheme.mediumGray),
                  const SizedBox(width: 6),
                  Text(
                    'All ${label}s',
                    style: const TextStyle(
                      color: AppTheme.mediumGray,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            ...options.map((option) {
              return DropdownMenuItem<String?>(
                value: option,
                child: Text(
                  option,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Function(bool) onSelected,
    required Color color,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? AppTheme.backgroundDark : color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? AppTheme.backgroundDark : color,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: AppTheme.elevatedSurface,
      selectedColor: color,
      checkmarkColor: AppTheme.backgroundDark,
      side: BorderSide(
        color: isSelected ? color : AppTheme.elevatedSurface,
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildLeadCard(BuildContext context, Lead lead) {
    final selectedLeads = ref.watch(selectedLeadsProvider);
    final isSelected = selectedLeads.contains(lead.id);
    final isNew = lead.status == LeadStatus.new_;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
              ? AppTheme.primaryGold.withOpacity(0.5)
              : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            // Store scroll position before navigating
            _storeScrollPosition();
            
            if (lead.status == LeadStatus.new_) {
              await _markLeadAsViewed(lead.id);
            }
            context.go('/leads/${lead.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Selection checkbox
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (bool? value) {
                      final currentSelected = ref.read(selectedLeadsProvider);
                      final newSelected = Set<String>.from(currentSelected);
                      
                      if (value == true) {
                        newSelected.add(lead.id);
                      } else {
                        newSelected.remove(lead.id);
                      }
                      
                      ref.read(selectedLeadsProvider.notifier).state = newSelected;
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    activeColor: AppTheme.primaryGold,
                    checkColor: Colors.black,
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryGold : AppTheme.mediumGray.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getStatusColor(lead.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      lead.businessName.isNotEmpty
                          ? lead.businessName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: _getStatusColor(lead.status),
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
                      // Title and status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lead.businessName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(lead.status).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getStatusLabel(lead.status),
                              style: TextStyle(
                                color: _getStatusColor(lead.status),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Location
                      Text(
                        lead.location,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.mediumGray,
                          letterSpacing: -0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Metrics row
                      Row(
                        children: [
                          if (lead.rating != null) ...[
                            Icon(
                              Icons.star,
                              size: 12,
                              color: AppTheme.warningOrange.withOpacity(0.8),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              lead.rating!.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.mediumGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (lead.reviewCount != null) ...[
                            Icon(
                              Icons.message,
                              size: 12,
                              color: AppTheme.accentCyan.withOpacity(0.8),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${lead.reviewCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.mediumGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (lead.hasWebsite) ...[
                            Icon(
                              Icons.language,
                              size: 12,
                              color: AppTheme.primaryBlue.withOpacity(0.8),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Website',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.mediumGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (lead.isCandidate)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 10,
                                    color: AppTheme.primaryGold,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Candidate',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primaryGold,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 8),
                          // Follow-up indicators
                          if (lead.hasUpcomingFollowUp)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 10,
                                    color: AppTheme.primaryBlue,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Follow-up',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primaryBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (lead.hasOverdueFollowUp)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.warningOrange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning,
                                    size: 10,
                                    color: AppTheme.warningOrange,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Overdue',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.warningOrange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Chevron
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.mediumGray.withOpacity(0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color.withOpacity(0.9),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              if (trend != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trend == 'hot' 
                        ? AppTheme.warningOrange.withOpacity(0.1)
                        : AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend == 'hot' 
                            ? Icons.local_fire_department
                            : Icons.trending_up,
                        size: 10,
                        color: trend == 'hot' 
                            ? AppTheme.warningOrange
                            : AppTheme.successGreen,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trend == 'hot' ? 'HOT' : '↗',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: trend == 'hot' 
                              ? AppTheme.warningOrange
                              : AppTheme.successGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.6),
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _mapPipelineLabelToStatus(String label) {
    switch (label.toLowerCase()) {
      case 'new':
        return 'new';
      case 'viewed':
        return 'viewed';
      case 'called':
        return 'called';
      case 'hot':
        return 'interested';
      case 'won':
        return 'converted';
      default:
        return label.toLowerCase();
    }
  }

  Widget _buildPipelineStep(String label, int count, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: count > 0 ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: count > 0 ? color.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: count > 0 ? color.withOpacity(0.3) : AppTheme.mediumGray.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: count > 0 ? color : AppTheme.mediumGray,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: count > 0 ? Colors.white : AppTheme.mediumGray,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPipelineArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.arrow_forward_ios,
        size: 10,
        color: AppTheme.mediumGray.withOpacity(0.5),
      ),
    );
  }
}

class _FilterModal extends StatefulWidget {
  final Map<String, List<String>> uniqueValues;
  final String? currentLocationFilter;
  final String? currentIndustryFilter;
  final String? currentSourceFilter;
  final Function(String?, String?, String?) onFiltersChanged;

  const _FilterModal({
    required this.uniqueValues,
    required this.currentLocationFilter,
    required this.currentIndustryFilter,
    required this.currentSourceFilter,
    required this.onFiltersChanged,
  });

  @override
  State<_FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<_FilterModal> {
  late String? locationFilter;
  late String? industryFilter;
  late String? sourceFilter;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    locationFilter = widget.currentLocationFilter;
    industryFilter = widget.currentIndustryFilter;
    sourceFilter = widget.currentSourceFilter;
  }

  void _applyFilters() {
    widget.onFiltersChanged(locationFilter, industryFilter, sourceFilter);
    Navigator.of(context).pop();
  }

  void _clearAllFilters() {
    setState(() {
      locationFilter = null;
      industryFilter = null;
      sourceFilter = null;
    });
  }

  List<String> _getFilteredOptions(List<String> options) {
    if (searchQuery.isEmpty) return options;
    return options
        .where((option) => option.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasChanges = locationFilter != widget.currentLocationFilter ||
                      industryFilter != widget.currentIndustryFilter ||
                      sourceFilter != widget.currentSourceFilter;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        height: 600,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.elevatedSurface),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.tune,
                      color: AppTheme.primaryGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Filter Leads',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppTheme.mediumGray),
                  ),
                ],
              ),
            ),
            
            // Search bar
            Padding(
              padding: const EdgeInsets.all(24),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search filter values...',
                  hintStyle: TextStyle(color: AppTheme.mediumGray.withOpacity(0.6)),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.mediumGray),
                  filled: true,
                  fillColor: AppTheme.elevatedSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
              ),
            ),

            // Filter sections
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildFilterSection(
                    'Location',
                    Icons.location_on,
                    AppTheme.primaryBlue,
                    _getFilteredOptions(widget.uniqueValues['locations'] ?? []),
                    locationFilter,
                    (value) => setState(() => locationFilter = value),
                  ),
                  const SizedBox(height: 24),
                  _buildFilterSection(
                    'Industry',
                    Icons.business,
                    AppTheme.primaryIndigo,
                    _getFilteredOptions(widget.uniqueValues['industries'] ?? []),
                    industryFilter,
                    (value) => setState(() => industryFilter = value),
                  ),
                  const SizedBox(height: 24),
                  _buildFilterSection(
                    'Source',
                    Icons.source,
                    AppTheme.accentPurple,
                    _getFilteredOptions(widget.uniqueValues['sources'] ?? []),
                    sourceFilter,
                    (value) => setState(() => sourceFilter = value),
                  ),
                ],
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.elevatedSurface),
                ),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _clearAllFilters,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.mediumGray,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.mediumGray),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _applyFilters,
                      icon: const Icon(Icons.check, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(hasChanges ? 'Apply Changes' : 'Apply'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(
    String title,
    IconData icon,
    Color color,
    List<String> options,
    String? selectedValue,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${options.length})',
              style: const TextStyle(
                color: AppTheme.mediumGray,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 120),
          decoration: BoxDecoration(
            color: AppTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: options.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    searchQuery.isNotEmpty ? 'No matches found' : 'No options available',
                    style: const TextStyle(color: AppTheme.mediumGray),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    // "All" option
                    ListTile(
                      dense: true,
                      leading: Radio<String?>(
                        value: null,
                        groupValue: selectedValue,
                        onChanged: onChanged,
                        activeColor: color,
                      ),
                      title: Text(
                        'All ${title}s',
                        style: TextStyle(
                          color: selectedValue == null ? color : Colors.white,
                          fontWeight: selectedValue == null ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      onTap: () => onChanged(null),
                    ),
                    ...options.map((option) {
                      final isSelected = selectedValue == option;
                      return ListTile(
                        dense: true,
                        leading: Radio<String?>(
                          value: option,
                          groupValue: selectedValue,
                          onChanged: onChanged,
                          activeColor: color,
                        ),
                        title: Text(
                          option,
                          style: TextStyle(
                            color: isSelected ? color : Colors.white,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => onChanged(option),
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }

}
