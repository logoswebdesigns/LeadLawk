import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/providers/filter_providers.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/entities/lead.dart';
import 'export_button.dart';

class LeadsFilterBar extends ConsumerStatefulWidget {
  const LeadsFilterBar({super.key});

  @override
  ConsumerState<LeadsFilterBar> createState() => _LeadsFilterBarState();
}

class _LeadsFilterBarState extends ConsumerState<LeadsFilterBar> {
  bool _statusExpanded = false;
  bool _qualityExpanded = false;
  bool _contentExpanded = false;
  bool _followUpExpanded = false;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildSearchBar(),
          _buildFilterSections(),
        ],
      ),
    );
  }

  Widget _buildGroupBySelector() {
    final groupBy = ref.watch(groupByOptionProvider);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: DropdownButton<GroupByOption>(
        value: groupBy,
        isDense: true,
        underline: const SizedBox(),
        icon: Icon(
          Icons.arrow_drop_down,
          color: Colors.white.withValues(alpha: 0.6),
          size: 20,
        ),
        dropdownColor: AppTheme.elevatedSurface,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
        ),
        items: [
          DropdownMenuItem(
            value: GroupByOption.none,
            child: Row(
              children: [
                Icon(Icons.list, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                const Text('No Grouping'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: GroupByOption.location,
            child: Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                const Text('By Location'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: GroupByOption.status,
            child: Row(
              children: [
                Icon(Icons.flag, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                const Text('By Status'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: GroupByOption.industry,
            child: Row(
              children: [
                Icon(Icons.business, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                const Text('By Industry'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: GroupByOption.hasWebsite,
            child: Row(
              children: [
                Icon(Icons.language, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                const Text('By Website'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: GroupByOption.pageSpeed,
            child: Row(
              children: [
                Icon(Icons.speed, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                const Text('By PageSpeed'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: GroupByOption.rating,
            child: Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                const Text('By Rating'),
              ],
            ),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            ref.read(currentUIStateProvider.notifier).updateGroupByOption(value);
            // Clear expanded groups when changing group by
            // Clear expanded groups automatically handled by state notifier
          }
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    final searchQuery = ref.watch(searchFilterProvider);
    
    // Sync controller text with provider state only when provider changes externally
    if (_searchController.text != searchQuery) {
      _searchController.text = searchQuery;
      // Move cursor to end of text
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                ref.read(currentFilterStateProvider.notifier).updateSearchFilter(value);
              },
              style: const TextStyle(color: Colors.white),
              textDirection: TextDirection.ltr,  // Ensure left-to-right text direction
              decoration: InputDecoration(
                hintText: 'Search leads...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(currentFilterStateProvider.notifier).updateSearchFilter('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.elevatedSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildGroupBySelector(),
          const SizedBox(width: 12),
          const ExportButton(),
        ],
      ),
    );
  }

  Widget _buildFilterSections() {
    return Column(
      children: [
        _buildActiveFiltersRow(),
        _buildFilterSection(
          title: 'Status',
          icon: Icons.flag,
          isExpanded: _statusExpanded,
          onToggle: () => setState(() => _statusExpanded = !_statusExpanded),
          child: _buildStatusFilters(),
        ),
        _buildFilterSection(
          title: 'Quality & Reviews',
          icon: Icons.star,
          isExpanded: _qualityExpanded,
          onToggle: () => setState(() => _qualityExpanded = !_qualityExpanded),
          child: _buildQualityFilters(),
        ),
        _buildFilterSection(
          title: 'Content & Website',
          icon: Icons.language,
          isExpanded: _contentExpanded,
          onToggle: () => setState(() => _contentExpanded = !_contentExpanded),
          child: _buildContentFilters(),
        ),
        _buildFilterSection(
          title: 'Follow-ups',
          icon: Icons.schedule,
          isExpanded: _followUpExpanded,
          onToggle: () => setState(() => _followUpExpanded = !_followUpExpanded),
          child: _buildFollowUpFilters(),
        ),
      ],
    );
  }

  Widget _buildActiveFiltersRow() {
    final candidatesOnly = ref.watch(candidatesOnlyProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final searchQuery = ref.watch(searchFilterProvider);
    final followUpFilter = ref.watch(followUpFilterProvider);
    final hasWebsiteFilter = ref.watch(hasWebsiteFilterProvider);
    final meetsRatingFilter = ref.watch(meetsRatingFilterProvider);
    final hasRecentReviewsFilter = ref.watch(hasRecentReviewsFilterProvider);
    final ratingRangeFilter = ref.watch(ratingRangeFilterProvider);
    final pageSpeedFilter = ref.watch(pageSpeedFilterProvider);
    
    final activeFilters = <Widget>[];
    
    if (candidatesOnly) {
      activeFilters.add(_buildActiveFilterChip(
        label: 'Candidates',
        onRemove: () => ref.read(currentFilterStateProvider.notifier).updateCandidatesOnly(false,
      )));
    }
    
    if (statusFilter != null) {
      activeFilters.add(_buildActiveFilterChip(
        label: statusFilter.toUpperCase(),
        onRemove: () => ref.read(currentFilterStateProvider.notifier).updateStatusFilter(null,
      )));
    }
    
    if (searchQuery.isNotEmpty) {
      activeFilters.add(_buildActiveFilterChip(
        label: 'Search: "$searchQuery"',
        onRemove: () => ref.read(currentFilterStateProvider.notifier).updateSearchFilter('',
      )));
    }
    
    if (followUpFilter != null) {
      activeFilters.add(_buildActiveFilterChip(
        label: followUpFilter == 'upcoming' ? 'Upcoming' : 'Overdue',
        onRemove: () => ref.read(currentFilterStateProvider.notifier).updateFollowUpFilter(null,
      )));
    }
    
    if (hasWebsiteFilter != null) {
      activeFilters.add(_buildActiveFilterChip(
        label: hasWebsiteFilter ? 'Has Website' : 'No Website',
        onRemove: () => ref.read(currentFilterStateProvider.notifier).updateHasWebsiteFilter(null,
      )));
    }
    
    if (meetsRatingFilter == true) {
      activeFilters.add(_buildActiveFilterChip(
        label: 'Quality Rating',
        onRemove: () => ref.read(currentFilterStateProvider.notifier).updateMeetsRatingFilter(null,
      )));
    }
    
    if (hasRecentReviewsFilter == true) {
      activeFilters.add(_buildActiveFilterChip(
        label: 'Recent Reviews',
        onRemove: () => ref.read(currentFilterStateProvider.notifier).updateHasRecentReviewsFilter(null,
      )));
    }
    
    if (ratingRangeFilter != null) {
      activeFilters.add(_buildActiveFilterChip(
        label: '$ratingRangeFilter Stars',
        onRemove: () => ref.read(currentFilterStateProvider.notifier).updateRatingRangeFilter(null,
      )));
    }
    
    if (pageSpeedFilter != null) {
      String label;
      switch (pageSpeedFilter) {
        case 'good':
          label = 'PageSpeed: Good';
          break;
        case 'moderate':
          label = 'PageSpeed: Moderate';
          break;
        case 'poor':
          label = 'PageSpeed: Poor';
          break;
        case 'untested':
          label = 'PageSpeed: Untested';
          break;
        default:
          label = 'PageSpeed';
      }
      activeFilters.add(_buildActiveFilterChip(
        label: label,
        onRemove: () => ref.read(currentFilterStateProvider.notifier).updatePageSpeedFilter(null,
      )));
    }

    if (activeFilters.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Active Filters',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (activeFilters.isNotEmpty)
                TextButton(
                  onPressed: _clearAllFilters,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: activeFilters,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.primaryGold,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppTheme.primaryGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusFilters() {
    final statusFilter = ref.watch(statusFilterProvider);
    final candidatesOnly = ref.watch(candidatesOnlyProvider);

    return Column(
      children: [
        _buildFilterRow([
          _buildFilterButton(
            label: 'Candidates',
            icon: Icons.star,
            isSelected: candidatesOnly,
            color: AppTheme.primaryGold,
            onPressed: () {
              ref.read(currentFilterStateProvider.notifier).updateCandidatesOnly(!candidatesOnly);
            },
          ),
        ]),
        const SizedBox(height: 12),
        _buildFilterRow([
          ...LeadStatus.values.map((status) {
            final label = _getStatusLabel(status);
            final isSelected = statusFilter == label.toLowerCase();
            return _buildFilterButton(
              label: label,
              icon: _getStatusIcon(status),
              isSelected: isSelected,
              color: _getStatusColor(status),
              onPressed: () {
                ref.read(currentFilterStateProvider.notifier).updateStatusFilter(isSelected ? null : label.toLowerCase());
              },
            );
          }),
        ]),
      ],
    );
  }

  Widget _buildQualityFilters() {
    final meetsRatingFilter = ref.watch(meetsRatingFilterProvider);
    final hasRecentReviewsFilter = ref.watch(hasRecentReviewsFilterProvider);
    final ratingRangeFilter = ref.watch(ratingRangeFilterProvider);
    final reviewCountRangeFilter = ref.watch(reviewCountRangeFilterProvider);

    return Column(
      children: [
        _buildFilterRow([
          _buildFilterButton(
            label: 'Quality Rating',
            icon: Icons.verified,
            isSelected: meetsRatingFilter == true,
            color: AppTheme.successGreen,
            onPressed: () {
              ref.read(currentFilterStateProvider.notifier).updateMeetsRatingFilter(meetsRatingFilter == true ? null : true);
            },
          ),
          _buildFilterButton(
            label: 'Recent Reviews',
            icon: Icons.schedule,
            isSelected: hasRecentReviewsFilter == true,
            color: AppTheme.primaryIndigo,
            onPressed: () {
              ref.read(currentFilterStateProvider.notifier).updateHasRecentReviewsFilter(hasRecentReviewsFilter == true ? null : true);
            },
          ),
        ]),
        const SizedBox(height: 12),
        _buildFilterRow([
          _buildFilterButton(
            label: '4+ Stars',
            icon: Icons.star,
            isSelected: ratingRangeFilter == '4+',
            color: AppTheme.warningOrange,
            onPressed: () {
              ref.read(currentFilterStateProvider.notifier).updateRatingRangeFilter(ratingRangeFilter == '4+' ? null : '4+');
            },
          ),
          _buildFilterButton(
            label: '50+ Reviews',
            icon: Icons.reviews,
            isSelected: reviewCountRangeFilter == '50+',
            color: AppTheme.accentPurple,
            onPressed: () {
              ref.read(currentFilterStateProvider.notifier).updateReviewCountRangeFilter(reviewCountRangeFilter == '50+' ? null : '50+');
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildContentFilters() {
    final hasWebsiteFilter = ref.watch(hasWebsiteFilterProvider);
    final pageSpeedFilter = ref.watch(pageSpeedFilterProvider);

    return Column(
      children: [
        _buildFilterRow([
          _buildFilterButton(
            label: 'Has Website',
            icon: Icons.language,
            isSelected: hasWebsiteFilter == true,
            color: AppTheme.accentCyan,
            onPressed: () {
              ref.read(currentFilterStateProvider.notifier).updateHasWebsiteFilter(hasWebsiteFilter == true ? null : true);
            },
          ),
          _buildFilterButton(
            label: 'No Website',
            icon: Icons.language_outlined,
            isSelected: hasWebsiteFilter == false,
            color: Colors.grey,
            onPressed: () {
              ref.read(currentFilterStateProvider.notifier).updateHasWebsiteFilter(hasWebsiteFilter == false ? null : false);
            },
          ),
        ]),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PageSpeed Score',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _buildFilterRow([
              _buildFilterButton(
                label: 'Good (90+)',
                icon: Icons.speed,
                isSelected: pageSpeedFilter == 'good',
                color: AppTheme.successGreen,
                onPressed: () {
                  ref.read(currentFilterStateProvider.notifier).updatePageSpeedFilter(pageSpeedFilter == 'good' ? null : 'good');
                },
              ),
              _buildFilterButton(
                label: 'Moderate (50-89)',
                icon: Icons.speed,
                isSelected: pageSpeedFilter == 'moderate',
                color: AppTheme.warningOrange,
                onPressed: () {
                  ref.read(currentFilterStateProvider.notifier).updatePageSpeedFilter(pageSpeedFilter == 'moderate' ? null : 'moderate');
                },
              ),
            ]),
            const SizedBox(height: 8),
            _buildFilterRow([
              _buildFilterButton(
                label: 'Poor (<50)',
                icon: Icons.speed,
                isSelected: pageSpeedFilter == 'poor',
                color: AppTheme.errorRed,
                onPressed: () {
                  ref.read(currentFilterStateProvider.notifier).updatePageSpeedFilter(pageSpeedFilter == 'poor' ? null : 'poor');
                },
              ),
              _buildFilterButton(
                label: 'Untested',
                icon: Icons.speed_outlined,
                isSelected: pageSpeedFilter == 'untested',
                color: Colors.grey,
                onPressed: () {
                  ref.read(currentFilterStateProvider.notifier).updatePageSpeedFilter(pageSpeedFilter == 'untested' ? null : 'untested');
                },
              ),
            ]),
          ],
        ),
      ],
    );
  }

  Widget _buildFollowUpFilters() {
    final followUpFilter = ref.watch(followUpFilterProvider);

    return Column(
      children: [
        _buildFilterRow([
          _buildFilterButton(
            label: 'Upcoming',
            icon: Icons.schedule,
            isSelected: followUpFilter == 'upcoming',
            color: AppTheme.primaryBlue,
            onPressed: () {
              ref.read(currentFilterStateProvider.notifier).updateFollowUpFilter(followUpFilter == 'upcoming' ? null : 'upcoming');
            },
          ),
          _buildFilterButton(
            label: 'Overdue',
            icon: Icons.warning,
            isSelected: followUpFilter == 'overdue',
            color: AppTheme.warningOrange,
            onPressed: () {
              ref.read(currentFilterStateProvider.notifier).updateFollowUpFilter(followUpFilter == 'overdue' ? null : 'overdue');
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildFilterRow(List<Widget> children) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }

  Widget _buildFilterButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.elevatedSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearAllFilters() {
    ref.read(currentFilterStateProvider.notifier).updateStatusFilter(null);
    ref.read(currentFilterStateProvider.notifier).updateCandidatesOnly(false);
    ref.read(currentFilterStateProvider.notifier).updateSearchFilter('');
    ref.read(currentFilterStateProvider.notifier).updateFollowUpFilter(null);
    ref.read(currentFilterStateProvider.notifier).updateHasWebsiteFilter(null);
    ref.read(currentFilterStateProvider.notifier).updateMeetsRatingFilter(null);
    ref.read(currentFilterStateProvider.notifier).updateHasRecentReviewsFilter(null);
    ref.read(currentFilterStateProvider.notifier).updateRatingRangeFilter(null);
    ref.read(currentFilterStateProvider.notifier).updateReviewCountRangeFilter(null);
    ref.read(currentFilterStateProvider.notifier).updatePageSpeedFilter(null);
    _searchController.clear();
  }

  String _getStatusLabel(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return 'NEW';
      case LeadStatus.viewed:
        return 'VIEWED';
      case LeadStatus.called:
        return 'CALLED';
      case LeadStatus.callbackScheduled:
        return 'CALLBACK';
      case LeadStatus.interested:
        return 'INTERESTED';
      case LeadStatus.converted:
        return 'CONVERTED';
      case LeadStatus.doNotCall:
        return 'DO NOT CALL';
      case LeadStatus.didNotConvert:
        return 'DID NOT CONVERT';
    }
  }

  IconData _getStatusIcon(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return Icons.fiber_new;
      case LeadStatus.viewed:
        return Icons.visibility;
      case LeadStatus.called:
        return Icons.call;
      case LeadStatus.callbackScheduled:
        return Icons.event;
      case LeadStatus.interested:
        return Icons.favorite;
      case LeadStatus.converted:
        return Icons.check_circle;
      case LeadStatus.doNotCall:
        return Icons.phone_disabled;
      case LeadStatus.didNotConvert:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return AppTheme.primaryBlue;
      case LeadStatus.viewed:
        return AppTheme.mediumGray;
      case LeadStatus.called:
        return AppTheme.warningOrange;
      case LeadStatus.callbackScheduled:
        return Colors.purple;
      case LeadStatus.interested:
        return AppTheme.successGreen;
      case LeadStatus.converted:
        return AppTheme.primaryGold;
      case LeadStatus.doNotCall:
        return AppTheme.errorRed;
      case LeadStatus.didNotConvert:
        return Colors.deepOrange;
    }
  }
}