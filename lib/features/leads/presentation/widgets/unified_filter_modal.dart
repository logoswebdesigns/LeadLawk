import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../pages/leads_list_page.dart';
import '../providers/paginated_leads_provider.dart';

class UnifiedFilterModal extends ConsumerStatefulWidget {
  const UnifiedFilterModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => const UnifiedFilterModal(),
    );
  }

  @override
  ConsumerState<UnifiedFilterModal> createState() => _UnifiedFilterModalState();
}

class _UnifiedFilterModalState extends ConsumerState<UnifiedFilterModal> {
  late TextEditingController searchController;
  late Set<LeadStatus> visibleStatuses;
  late bool candidatesOnly;
  late SortOption sortOption;
  late bool sortAscending;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize with current filter values
    searchController = TextEditingController(text: ref.read(searchFilterProvider));
    
    // Initialize visible statuses (inverse of hidden)
    final hiddenStatuses = ref.read(hiddenStatusesProvider);
    visibleStatuses = LeadStatus.values
        .where((status) => !hiddenStatuses.contains(status.name))
        .toSet();
    
    candidatesOnly = ref.read(candidatesOnlyProvider);
    final sortState = ref.read(sortStateProvider);
    sortOption = sortState.option;
    sortAscending = sortState.ascending;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeFilterCount = _getActiveFilterCount();
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark,
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.slider_horizontal_3,
                  color: AppTheme.primaryGold,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filters & Sort',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (activeFilterCount > 0)
                      Text(
                        '$activeFilterCount active filter${activeFilterCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: _resetAllFilters,
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      color: Colors.red.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Section
                  _buildSectionHeader('Search', CupertinoIcons.search),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by business name or phone...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                      prefixIcon: Icon(
                        CupertinoIcons.search,
                        color: AppTheme.primaryGold,
                        size: 20,
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                CupertinoIcons.xmark_circle_fill,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              onPressed: () {
                                setState(() {
                                  searchController.clear();
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.elevatedSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryGold),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Status Filter Section
                  _buildSectionHeader('Status Visibility', CupertinoIcons.eye),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQuickAction(
                        'Show All',
                        () => setState(() => 
                          visibleStatuses = Set.from(LeadStatus.values)),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickAction(
                        'Hide All',
                        () => setState(() => visibleStatuses.clear()),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickAction(
                        'Unprocessed Only',
                        () => setState(() {
                          visibleStatuses = {
                            LeadStatus.new_,
                            LeadStatus.viewed,
                            LeadStatus.interested,
                            LeadStatus.callbackScheduled,
                          };
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStatusGrid(),
                  
                  const SizedBox(height: 24),
                  
                  // Sort Section
                  _buildSectionHeader('Sort By', CupertinoIcons.sort_down),
                  const SizedBox(height: 12),
                  _buildSortOptions(),
                  
                  const SizedBox(height: 24),
                  
                  // Additional Filters
                  _buildSectionHeader('Additional Filters', CupertinoIcons.flag),
                  const SizedBox(height: 12),
                  _buildAdditionalFilters(),
                ],
              ),
            ),
          ),
          
          // Apply Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    activeFilterCount > 0 
                      ? 'Apply Filters ($activeFilterCount active)'
                      : 'Apply Filters',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGold),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryGold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryGold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: LeadStatus.values.map((status) {
        final isVisible = visibleStatuses.contains(status);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isVisible) {
                visibleStatuses.remove(status);
              } else {
                visibleStatuses.add(status);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isVisible 
                ? _getStatusColor(status).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isVisible 
                  ? _getStatusColor(status).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVisible ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                  size: 14,
                  color: isVisible 
                    ? _getStatusColor(status)
                    : Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 6),
                Text(
                  _getStatusLabel(status),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isVisible 
                      ? _getStatusColor(status)
                      : Colors.white.withValues(alpha: 0.3),
                    decoration: isVisible ? null : TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSortOptions() {
    return Column(
      children: [
        // Sort field selection
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildSortOptionTile(SortOption.newest, 'Newest First'),
              _buildSortOptionTile(SortOption.rating, 'Rating'),
              _buildSortOptionTile(SortOption.reviews, 'Review Count'),
              _buildSortOptionTile(SortOption.alphabetical, 'Alphabetical'),
              _buildSortOptionTile(SortOption.pageSpeed, 'Page Speed'),
              _buildSortOptionTile(SortOption.conversion, 'Conversion Score'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Sort direction
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => sortAscending = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !sortAscending 
                        ? AppTheme.primaryGold.withValues(alpha: 0.2)
                        : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.sort_down,
                          size: 16,
                          color: !sortAscending 
                            ? AppTheme.primaryGold
                            : Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Descending',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: !sortAscending 
                              ? AppTheme.primaryGold
                              : Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => sortAscending = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: sortAscending 
                        ? AppTheme.primaryGold.withValues(alpha: 0.2)
                        : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.sort_up,
                          size: 16,
                          color: sortAscending 
                            ? AppTheme.primaryGold
                            : Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ascending',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: sortAscending 
                              ? AppTheme.primaryGold
                              : Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSortOptionTile(SortOption option, String label) {
    final isSelected = sortOption == option;
    return GestureDetector(
      onTap: () => setState(() => sortOption = option),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? AppTheme.primaryGold.withValues(alpha: 0.1)
            : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isSelected 
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.circle,
              size: 20,
              color: isSelected 
                ? AppTheme.primaryGold
                : Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected 
                  ? AppTheme.primaryGold
                  : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: const Text(
          'Candidates Only',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Show only businesses without websites',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        value: candidatesOnly,
        onChanged: (value) => setState(() => candidatesOnly = value),
        activeColor: AppTheme.primaryGold,
      ),
    );
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (searchController.text.isNotEmpty) count++;
    if (visibleStatuses.length < LeadStatus.values.length) count++;
    if (candidatesOnly) count++;
    return count;
  }

  void _resetAllFilters() {
    setState(() {
      searchController.clear();
      visibleStatuses = Set.from(LeadStatus.values);
      candidatesOnly = false;
      sortOption = SortOption.newest;
      sortAscending = false;
    });
  }

  void _applyFilters() {
    // Update all providers
    ref.read(searchFilterProvider.notifier).state = searchController.text;
    ref.read(candidatesOnlyProvider.notifier).state = candidatesOnly;
    ref.read(sortStateProvider.notifier).state = SortState(
      option: sortOption,
      ascending: sortAscending,
    );
    
    // Convert visible statuses to hidden statuses
    final hiddenStatuses = LeadStatus.values
        .where((status) => !visibleStatuses.contains(status))
        .map((status) => status.name)
        .toSet();
    ref.read(hiddenStatusesProvider.notifier).state = hiddenStatuses;
    
    Navigator.pop(context);
  }

  String _getStatusLabel(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_: return 'New';
      case LeadStatus.viewed: return 'Viewed';
      case LeadStatus.called: return 'Called';
      case LeadStatus.interested: return 'Interested';
      case LeadStatus.converted: return 'Won';
      case LeadStatus.didNotConvert: return 'Lost';
      case LeadStatus.callbackScheduled: return 'Callback';
      case LeadStatus.doNotCall: return 'DNC';
    }
  }

  Color _getStatusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_: return const Color(0xFF007AFF);
      case LeadStatus.viewed: return const Color(0xFF5856D6);
      case LeadStatus.called: return const Color(0xFFFF9500);
      case LeadStatus.interested: return const Color(0xFF34C759);
      case LeadStatus.converted: return const Color(0xFF30D158);
      case LeadStatus.didNotConvert: return const Color(0xFFFF3B30);
      case LeadStatus.callbackScheduled: return const Color(0xFF5AC8FA);
      case LeadStatus.doNotCall: return const Color(0xFF8E8E93);
    }
  }
}