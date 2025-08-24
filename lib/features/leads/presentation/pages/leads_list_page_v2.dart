import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/job_provider.dart';
import '../providers/server_status_provider.dart';
import '../widgets/loading_state.dart';
import '../widgets/empty_state.dart';

final leadsProvider = FutureProvider.autoDispose<List<Lead>>(
  (ref) async {
    final repository = ref.watch(leadsRepositoryProvider);
    
    // Get filter parameters from dedicated providers
    final status = ref.watch(statusFilterProvider);
    final search = ref.watch(searchFilterProvider);
    final candidatesOnly = ref.watch(candidatesOnlyProvider);
    
    final result = await repository.getLeads(
      status: status,
      search: search.isEmpty ? null : search,
      candidatesOnly: candidatesOnly,
    );
    
    return result.fold(
      (failure) => throw Exception(failure.message),
      (leads) => leads,
    );
  },
);

// Dedicated providers for filters to prevent unnecessary rebuilds
final statusFilterProvider = StateProvider<String?>((ref) => null);
final searchFilterProvider = StateProvider<String>((ref) => '');
final candidatesOnlyProvider = StateProvider<bool>((ref) => false);

class LeadsListPageV2 extends ConsumerStatefulWidget {
  final String? initialFilter;

  const LeadsListPageV2({super.key, this.initialFilter});

  @override
  ConsumerState<LeadsListPageV2> createState() => _LeadsListPageV2State();
}

class _LeadsListPageV2State extends ConsumerState<LeadsListPageV2> {
  final _searchController = TextEditingController();
  String? _lastIndustry;
  String? _lastLocation;
  final List<String> _loadingLogs = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter == 'candidates') {
      Future.microtask(() {
        ref.read(candidatesOnlyProvider.notifier).state = true;
      });
    }
    _loadLastScrapeContext();
    _addLoadingLog('Initializing LeadLawk...');
    
    // Set up search debouncing
    _searchController.addListener(_onSearchChanged);
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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return AppTheme.mediumGray;
      case LeadStatus.called:
        return AppTheme.warningOrange;
      case LeadStatus.interested:
        return AppTheme.primaryBlue;
      case LeadStatus.converted:
        return AppTheme.successGreen;
      case LeadStatus.dnc:
        return AppTheme.darkGray;
    }
  }

  String _getStatusLabel(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return 'NEW';
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

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadsProvider);
    final serverState = ref.watch(serverStatusProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final candidatesOnly = ref.watch(candidatesOnlyProvider);

    // Add server status to logs
    if (serverState.status == ServerStatus.checking) {
      _addLoadingLog('Checking server connection...');
    } else if (serverState.status == ServerStatus.online) {
      _addLoadingLog('Server connected successfully');
    } else if (serverState.status == ServerStatus.starting) {
      _addLoadingLog('Starting server...');
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/leadlawk-logo.png',
                    height: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LeadLawk',
                    style: TextStyle(
                      color: AppTheme.darkGray,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryIndigo.withOpacity(0.05),
                      Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.accentPurple.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.primaryBlue.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              _buildServerStatusBadge(serverState),
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryIndigo,
                          AppTheme.accentPurple,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryIndigo.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () => context.go('/scrape'),
                  tooltip: 'Run Scrape',
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  if (_lastIndustry != null && _lastLocation != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryIndigo.withOpacity(0.1),
                            AppTheme.accentPurple.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryIndigo.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history,
                            size: 16,
                            color: AppTheme.primaryIndigo,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Last search: $_lastIndustry • $_lastLocation',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryIndigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundGray,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or phone...',
                        hintStyle: TextStyle(
                          color: AppTheme.mediumGray.withOpacity(0.7),
                        ),
                        prefixIcon: Icon(
                          CupertinoIcons.search,
                          color: AppTheme.mediumGray,
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
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip(
                          label: 'Candidates',
                          icon: Icons.star,
                          isSelected: candidatesOnly,
                          onSelected: (selected) {
                            ref.read(candidatesOnlyProvider.notifier).state = selected;
                          },
                          color: AppTheme.accentPurple,
                        ),
                        const SizedBox(width: 8),
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
                ],
              ),
            ),
          ),
          leadsAsync.when(
            data: (leads) {
              if (leads.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.inbox,
                    title: 'No leads found',
                    description: candidatesOnly
                        ? 'No candidates match your criteria. Try adjusting your filters or run a new scrape.'
                        : 'Start by running a scrape to find potential leads in your area.',
                    buttonText: 'Run Scrape',
                    onButtonPressed: () => context.go('/scrape'),
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
            color: isSelected ? Colors.white : color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: color.withOpacity(0.1),
      selectedColor: color,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: color.withOpacity(0.3),
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildLeadCard(BuildContext context, Lead lead) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/leads/${lead.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getStatusColor(lead.status),
                        _getStatusColor(lead.status).withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      lead.businessName.isNotEmpty
                          ? lead.businessName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.businessName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkGray,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: AppTheme.mediumGray,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lead.phone,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.mediumGray,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (lead.rating != null)
                            _buildInfoBadge(
                              icon: Icons.star,
                              label: '${lead.rating!.toStringAsFixed(1)}',
                              color: AppTheme.warningOrange,
                            ),
                          if (lead.reviewCount != null)
                            _buildInfoBadge(
                              icon: Icons.rate_review,
                              label: '${lead.reviewCount}',
                              color: AppTheme.primaryBlue,
                            ),
                          if (lead.hasWebsite)
                            _buildInfoBadge(
                              icon: Icons.language,
                              label: 'Website',
                              color: AppTheme.successGreen,
                            ),
                          if (lead.isCandidate)
                            _buildInfoBadge(
                              icon: Icons.verified,
                              label: 'Candidate',
                              color: AppTheme.accentPurple,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(lead.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatusColor(lead.status).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _getStatusLabel(lead.status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _getStatusColor(lead.status),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.chevron_right,
                      color: AppTheme.mediumGray.withOpacity(0.5),
                    ),
                  ],
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
}
