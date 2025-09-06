import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/paginated_leads_provider.dart';
import '../providers/auto_refresh_provider.dart';
import 'sort_options_modal.dart';
import 'unified_filter_modal.dart';
import '../providers/filter_providers.dart' as presentation_providers;
import '../../domain/providers/filter_providers.dart' as domain_providers;
import '../../domain/entities/filter_state.dart';

class SortBar extends ConsumerStatefulWidget {
  const SortBar({super.key});

  @override
  ConsumerState<SortBar> createState() => _SortBarState();
}

class _SortBarState extends ConsumerState<SortBar> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    setState(() {
      _isRefreshing = true;
    });
    _rotationController.repeat();
    
    // Increment refresh trigger to force refresh
    ref.read(refreshTriggerProvider.notifier).state++;
    ref.read(paginatedLeadsProvider.notifier).refreshLeads();
    
    // Wait a bit for the refresh to start
    await Future.delayed(Duration(milliseconds: 500));
    
    try {
      // Wait for the leads to reload
      // Wait for refresh to complete
      await Future.delayed(Duration(milliseconds: 100));
    } catch (e) {
      // Handle error silently - the error will be shown in the leads list
    }
    
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
      _rotationController.stop();
      _rotationController.reset();
      
      // Success feedback
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortState = ref.watch(presentation_providers.sortStateProvider);
    final sortOption = sortState.option;
    final sortAscending = sortState.ascending;
    final paginatedState = ref.watch(filteredPaginatedLeadsProvider);
    final isSelectionMode = ref.watch(presentation_providers.isSelectionModeProvider);
    final autoRefresh = ref.watch(autoRefreshLeadsProvider);
    final pendingUpdates = ref.watch(pendingLeadsUpdateProvider);
    
    // Calculate active filter count
    final searchFilter = ref.watch(presentation_providers.searchFilterProvider);
    final hiddenStatuses = ref.watch(domain_providers.hiddenStatusesProvider);
    final candidatesOnly = ref.watch(presentation_providers.candidatesOnlyProvider);
    int activeFilterCount = 0;
    if (searchFilter.isNotEmpty) activeFilterCount++;
    if (hiddenStatuses.isNotEmpty) activeFilterCount++;
    if (candidatesOnly) activeFilterCount++;
    
    // Don't show this bar when in selection mode
    if (isSelectionMode) {
      return SizedBox.shrink();
    }
    
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Padding(padding: EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Lead count
            Text(
              '${paginatedState.total} leads',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            // Refresh button
            GestureDetector(
              onTap: _isRefreshing ? null : _handleRefresh,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isRefreshing 
                      ? AppTheme.primaryGold.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: _isRefreshing 
                      ? Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RotationTransition(
                      turns: _rotationController,
                      child: Icon(
                        CupertinoIcons.arrow_clockwise,
                        size: 14,
                        color: _isRefreshing 
                            ? AppTheme.primaryGold
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isRefreshing ? 'Refreshing...' : 'Refresh',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isRefreshing 
                            ? AppTheme.primaryGold
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Auto-refresh toggle
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(autoRefreshLeadsProvider.notifier).state = !autoRefresh;
                
                // If turning on auto-refresh and there are pending updates, refresh immediately
                if (!autoRefresh && pendingUpdates > 0) {
                  ref.read(pendingLeadsUpdateProvider.notifier).state = 0;
                  ref.read(paginatedLeadsProvider.notifier).refreshLeads();
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: autoRefresh 
                      ? AppTheme.primaryGold.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: autoRefresh 
                      ? Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Icon(
                          autoRefresh ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt,
                          size: 14,
                          color: autoRefresh 
                              ? AppTheme.primaryGold
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                        if (pendingUpdates > 0 && !autoRefresh)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.backgroundDark, width: 1),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      autoRefresh ? 'Auto' : 'Manual',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: autoRefresh 
                            ? AppTheme.primaryGold
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Filter button  
            GestureDetector(
              onTap: () => UnifiedFilterModal.show(context),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: activeFilterCount > 0
                      ? AppTheme.primaryGold.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: activeFilterCount > 0
                      ? Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Icon(
                          CupertinoIcons.slider_horizontal_3,
                          size: 14,
                          color: activeFilterCount > 0
                              ? AppTheme.primaryGold
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                        if (activeFilterCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryGold,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                activeFilterCount.toString(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: activeFilterCount > 0
                            ? AppTheme.primaryGold
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Select button
            GestureDetector(
              onTap: () => ref.read(presentation_providers.isSelectionModeProvider.notifier).state = true,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.checkmark_circle,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Select',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Sort button
            GestureDetector(
              onTap: () => SortOptionsModal.show(context),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      sortAscending 
                          ? CupertinoIcons.arrow_up 
                          : CupertinoIcons.arrow_down,
                      size: 14,
                      color: AppTheme.primaryGold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getSortLabel(sortOption),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.newest: return 'Newest';
      case SortOption.rating: return 'Rating';
      case SortOption.reviews: return 'Reviews';
      case SortOption.alphabetical: return 'A-Z';
      case SortOption.pageSpeed: return 'Speed';
      case SortOption.conversion: return 'Score';
    }
  }
}