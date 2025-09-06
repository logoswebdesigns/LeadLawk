import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/debug_logger.dart';
import '../providers/filter_providers.dart' as presentation_providers;
import '../../domain/entities/filter_state.dart';

class SortOptionsModal extends ConsumerWidget {
  const SortOptionsModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const SortOptionsModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortState = ref.watch(presentation_providers.sortStateProvider);
    final currentSort = sortState.option;
    final isAscending = sortState.ascending;
    
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
                        DebugLogger.log('🔄 SORT MODAL: Toggling sort direction from ${isAscending ? "ascending" : "descending"} to ${!isAscending ? "ascending" : "descending"}');
                        // Update only the ascending property of the combined state
                        ref.read(presentation_providers.sortStateProvider.notifier).state = sortState.copyWith(ascending: !isAscending);
                        DebugLogger.log('🔄 SORT MODAL: Sort direction toggled');
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
                              isAscending 
                                  ? CupertinoIcons.arrow_up 
                                  : CupertinoIcons.arrow_down,
                              size: 14,
                              color: AppTheme.primaryGold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isAscending ? 'Ascending' : 'Descending',
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
                    children: SortOption.values.map((option) => 
                      _buildSortOption(context, ref, option, currentSort == option)
                    ).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(
    BuildContext context, 
    WidgetRef ref, 
    SortOption option, 
    bool isSelected
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // For PageSpeed, always start with ascending (lowest scores first)
          // For others, keep current direction or use default
          final newAscending = option == SortOption.pageSpeed 
              ? true 
              : ref.read(presentation_providers.sortStateProvider).ascending;
          
          // Update the entire sort state atomically - no race conditions!
          ref.read(presentation_providers.sortStateProvider.notifier).state = SortState(
            option: option,
            ascending: newAscending,
          );
          
          // Close the modal
          Navigator.of(context).pop();
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
}