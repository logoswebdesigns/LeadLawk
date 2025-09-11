import 'package:flutter/material.dart';
import '../../domain/providers/filter_providers.dart' as domain_providers;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../../../../core/utils/debug_logger.dart';
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
  
  @override
  void initState() {
    super.initState();
    
    // Initialize with current filter values
    searchController = TextEditingController(text: ref.read(domain_providers.searchFilterProvider));
    
    // Initialize visible statuses from the current API filter state
    final currentState = ref.read(paginatedLeadsProvider);
    if (currentState.filters.statuses != null && currentState.filters.statuses!.isNotEmpty) {
      // If we have specific statuses in the filter, use those
      visibleStatuses = currentState.filters.statuses!
          .map((statusName) => LeadStatus.values.firstWhere((s) => s.name == statusName))
          .toSet();
    } else if (currentState.filters.status != null) {
      // If we have a single status filter, use that
      visibleStatuses = {LeadStatus.values.firstWhere((s) => s.name == currentState.filters.status)};
    } else {
      // Default to NEW and VIEWED as per our default filters
      visibleStatuses = {LeadStatus.new_, LeadStatus.viewed};
    }
    
    candidatesOnly = ref.read(domain_providers.candidatesOnlyProvider);
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
            padding: EdgeInsets.fromLTRB(24, 24, 16, 16),
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
                        style: const TextStyle(
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
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
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
                        borderSide: const BorderSide(color: AppTheme.primaryGold),
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
                  
                  // Additional Filters
                  _buildSectionHeader('Additional Filters', CupertinoIcons.flag),
                  const SizedBox(height: 12),
                  _buildAdditionalFilters(),
                ],
              ),
            ),
          ),
          
          // Apply Button and Set as Default
          Container(
            padding: EdgeInsets.all(24),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 16),
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
                  const SizedBox(height: 12),
                  // Set as default button
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saveAsDefault,
                          icon: Icon(Icons.save_alt, size: 18),
                          label: const Text('Save as Default'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryGold,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _clearDefaults,
                        icon: Icon(Icons.clear, size: 18),
                        label: const Text('Clear'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryGold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
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
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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


  Widget _buildAdditionalFilters() {
    return Container(
      padding: EdgeInsets.all(12),
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
    });
  }

  void _applyFilters() {
    // Following the Command Pattern for filter application
    // Each filter change triggers a new API query, not client-side filtering
    
    // Update search filter
    ref.read(domain_providers.currentFilterStateProvider.notifier).updateSearchFilter(searchController.text);
    
    // Update candidates only filter  
    ref.read(domain_providers.currentFilterStateProvider.notifier).updateCandidatesOnly(candidatesOnly);
    
    // Status filtering: Convert selection to API-compatible format
    // Following Riverpod's Filter Pattern - single selected status for API query
    // Handle multiple status selection properly
    List<String>? selectedStatuses;
    String? singleStatus;
    
    if (visibleStatuses.isEmpty || visibleStatuses.length == LeadStatus.values.length) {
      // No filter or all selected - don't filter
      selectedStatuses = null;
      singleStatus = null;
      DebugLogger.network('🔍 FILTER: No status filter or all statuses selected');
    } else if (visibleStatuses.length == 1) {
      // Single status selected - use single status parameter for backward compatibility
      singleStatus = visibleStatuses.first.name;
      selectedStatuses = null;
      DebugLogger.network('🔍 FILTER: Single status selected for API query: $singleStatus');
    } else {
      // Multiple statuses selected - use the new statuses parameter
      selectedStatuses = visibleStatuses.map((s) => s.name).toList();
      singleStatus = null;
      DebugLogger.network('🔍 FILTER: Multiple statuses selected for API query: $selectedStatuses');
    }
    
    // Update filters directly in the paginated leads provider
    ref.read(paginatedLeadsProvider.notifier).updateFilters(
      status: singleStatus,
      statuses: selectedStatuses,
      search: searchController.text.isEmpty ? null : searchController.text,
      candidatesOnly: candidatesOnly,
    );
    
    // Also update hidden statuses for UI consistency
    // final hiddenStatuses = LeadStatus.values
    //     .where((status) => !visibleStatuses.contains(status))
    //     .map((status) => status.name)
    //     .toSet();
    // Note: hiddenStatusesProvider is computed, need to update via filter state
    
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

  Future<void> _saveAsDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create a map of current filter settings
      final defaultSettings = {
        'visibleStatuses': visibleStatuses.map((s) => s.index).toList(),
        'candidatesOnly': candidatesOnly,
        'searchText': searchController.text,
      };
      
      // Save to SharedPreferences
      await prefs.setString('default_filter_settings', json.encode(defaultSettings));
      
      DebugLogger.log('✅ Default filter settings saved');
      
      // Show confirmation snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Default filters saved'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      DebugLogger.log('❌ Error saving default filters: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save defaults: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _clearDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('default_filter_settings');
      
      DebugLogger.log('✅ Default filter settings cleared');
      
      // Show confirmation snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.clear, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Default filters cleared'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      DebugLogger.log('❌ Error clearing default filters: $e');
    }
  }
}