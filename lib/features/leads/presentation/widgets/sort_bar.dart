import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../pages/leads_list_page.dart';
import 'sort_options_modal.dart';

class SortBar extends ConsumerWidget {
  const SortBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortOption = ref.watch(sortOptionProvider);
    final sortAscending = ref.watch(sortAscendingProvider);
    final leadsAsync = ref.watch(leadsProvider);
    final isSelectionMode = ref.watch(isSelectionModeProvider);
    
    // Don't show this bar when in selection mode
    if (isSelectionMode) {
      return const SizedBox.shrink();
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Lead count
            leadsAsync.when(
              data: (leads) => Text(
                '${leads.length} leads',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const Spacer(),
            // Select button
            GestureDetector(
              onTap: () => ref.read(isSelectionModeProvider.notifier).state = true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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