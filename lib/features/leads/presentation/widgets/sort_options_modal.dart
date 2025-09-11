import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/debug_logger.dart';
import '../providers/filter_providers.dart' as presentation_providers;
import '../providers/paginated_leads_provider.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/providers/filter_providers.dart' as domain_providers;

class SortOptionsModal extends ConsumerStatefulWidget {
  const SortOptionsModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SortOptionsModal(),
    );
  }

  @override
  ConsumerState<SortOptionsModal> createState() => _SortOptionsModalState();
}

class _SortOptionsModalState extends ConsumerState<SortOptionsModal> {
  late SortOption sortOption;
  late bool sortAscending;
  SortOption? defaultSortOption;
  bool? defaultSortAscending;
  
  @override
  void initState() {
    super.initState();
    
    // Use domain provider as the single source of truth
    final sortState = ref.read(domain_providers.sortStateProvider);
    sortOption = sortState.option;
    sortAscending = sortState.ascending;
    
    // Load saved default sort preference
    _loadDefaultSort();
    
    DebugLogger.log('🔍 SORT MODAL: Initialized with sortOption=${sortOption.name} (index=${sortOption.index}), ascending=$sortAscending');
  }
  
  Future<void> _loadDefaultSort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('default_sort_settings');
      if (settingsJson != null) {
        final settings = json.decode(settingsJson);
        setState(() {
          defaultSortOption = SortOption.values[settings['sortOption'] ?? 0];
          defaultSortAscending = settings['sortAscending'] ?? false;
        });
        DebugLogger.log('📌 Loaded default sort: ${defaultSortOption?.name} (${defaultSortAscending == true ? "asc" : "desc"})');
      }
    } catch (e) {
      DebugLogger.log('No saved default sort preferences');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Log current state at build time to catch any changes
    DebugLogger.log('🏗️ SORT MODAL BUILD: sortOption=${sortOption.name}, ascending=$sortAscending');
    
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.elevatedSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sort By',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    // Direction toggle
                    GestureDetector(
                      onTap: () {
                        final newAscending = !sortAscending;
                        setState(() => sortAscending = newAscending);
                        // Also update the domain provider immediately with the new value
                        _applySort(sortOption, newAscending);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
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
                              sortAscending ? 'Ascending' : 'Descending',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Sort options - make scrollable
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: SortOption.values.map((option) {
                      final isSelected = sortOption == option;
                      DebugLogger.log('📋 SORT MODAL: Checking ${option.name} (${option.index}) == ${sortOption.name} (${sortOption.index}) => $isSelected');
                      if (isSelected) {
                        DebugLogger.log('🎯 SORT MODAL: Option ${option.name} is selected');
                      }
                      return _buildSortOption(context, option, isSelected);
                    }).toList(),
                  ),
                ),
              ),
              // Action buttons at bottom
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveAsDefault,
                    icon: Icon(Icons.star, size: 18),
                    label: const Text('Set as Default'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(
    BuildContext context, 
    SortOption option, 
    bool isSelected
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Set appropriate default direction when switching options
          final bool newAscending;
          if (option != sortOption) {
            newAscending = switch (option) {
              SortOption.pageSpeed => true,      // Lowest scores first (ascending)
              SortOption.newest => false,         // Newest first (descending)
              SortOption.rating => false,         // Highest rating first (descending)
              SortOption.reviews => false,        // Most reviews first (descending)
              SortOption.alphabetical => true,    // A-Z (ascending)
              SortOption.conversion => false,     // Highest conversion first (descending)
            };
          } else {
            // If clicking the same option, keep current direction
            newAscending = sortAscending;
          }
          
          // Apply the sort immediately
          _applySort(option, newAscending);
          
          // Close the modal after applying
          Navigator.pop(context);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(
                _getOptionIcon(option),
                size: 20,
                color: isSelected 
                    ? AppTheme.primaryGold 
                    : Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getOptionLabel(option),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected 
                            ? Colors.white 
                            : Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      _getOptionDescription(option),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              // Show star if this is the saved default
              if (option == defaultSortOption)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.star,
                    size: 20,
                    color: AppTheme.primaryGold.withValues(alpha: 0.6),
                  ),
                ),
              // Show checkmark if currently selected
              if (isSelected)
                Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 22,
                  color: AppTheme.primaryGold,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getOptionIcon(SortOption option) {
    switch (option) {
      case SortOption.newest:
        return CupertinoIcons.clock;
      case SortOption.rating:
        return CupertinoIcons.star_fill;
      case SortOption.reviews:
        return CupertinoIcons.chat_bubble_2_fill;
      case SortOption.alphabetical:
        return CupertinoIcons.textformat_abc;
      case SortOption.pageSpeed:
        return CupertinoIcons.speedometer;
      case SortOption.conversion:
        return CupertinoIcons.chart_bar_fill;
    }
  }

  String _getOptionLabel(SortOption option) {
    switch (option) {
      case SortOption.newest:
        return 'Newest First';
      case SortOption.rating:
        return 'Highest Rating';
      case SortOption.reviews:
        return 'Most Reviews';
      case SortOption.alphabetical:
        return 'Alphabetical';
      case SortOption.pageSpeed:
        return 'PageSpeed Score';
      case SortOption.conversion:
        return 'Conversion Score';
    }
  }

  String _getOptionDescription(SortOption option) {
    switch (option) {
      case SortOption.newest:
        return 'Recently added leads first';
      case SortOption.rating:
        return 'Sort by business rating';
      case SortOption.reviews:
        return 'Sort by review count';
      case SortOption.alphabetical:
        return 'Sort by business name';
      case SortOption.pageSpeed:
        return 'Sort by website performance';
      case SortOption.conversion:
        return 'Sort by conversion potential';
    }
  }
  
  void _applySort(SortOption option, bool ascending) {
    // Update domain provider (single source of truth)
    ref.read(domain_providers.currentSortStateProvider.notifier).updateSort(option, ascending);
    
    // Update filters directly in the paginated leads provider
    final sortState = SortState(option: option, ascending: ascending);
    ref.read(paginatedLeadsProvider.notifier).updateFilters(
      status: null,
      statuses: null,
      search: null,  // Keep existing search
      candidatesOnly: null,
      sortBy: sortState.sortField,
      sortAscending: sortState.ascending,
    );
  }
  
  void _resetSort() {
    setState(() {
      sortOption = SortOption.newest;
      sortAscending = false;
    });
  }
  
  Future<void> _saveAsDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get current sort state from provider
      final currentSortState = ref.read(domain_providers.sortStateProvider);
      
      final defaultSettings = {
        'sortOption': currentSortState.option.index,
        'sortAscending': currentSortState.ascending,
      };
      
      await prefs.setString('default_sort_settings', json.encode(defaultSettings));
      
      // Update local state to show the star immediately
      setState(() {
        defaultSortOption = currentSortState.option;
        defaultSortAscending = currentSortState.ascending;
      });
      
      DebugLogger.log('✅ Default sort settings saved: ${currentSortState.option.name} (${currentSortState.ascending ? "asc" : "desc"})');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.star, color: Colors.white),
                const SizedBox(width: 8),
                Text('Default set to ${_getOptionLabel(currentSortState.option)}'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      DebugLogger.log('❌ Error saving default sort: $e');
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
}