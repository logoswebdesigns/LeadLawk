import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/providers/filter_providers.dart';
import '../../domain/entities/filter_state.dart';
import 'advanced_filter_search.dart';

class AdvancedFilterBar extends ConsumerStatefulWidget {
  const AdvancedFilterBar({super.key});

  @override
  ConsumerState<AdvancedFilterBar> createState() => AdvancedFilterBarState();
}

class AdvancedFilterBarState extends ConsumerState<AdvancedFilterBar> {
  bool showAdvancedFilters = false;
  final searchController = TextEditingController();
  Timer? debounceTimer;

  @override
  void dispose() {
    debounceTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSearchBar(),
          const SizedBox(height: 12),
          buildStatusFilters(),
          const SizedBox(height: 12),
          _buildSortingRow(),
          const SizedBox(height: 12),
          _buildQuickFilters(),
          if (showAdvancedFilters) ...[
            const SizedBox(height: 12),
            _buildAdvancedFilterSection(),
          ],
          const SizedBox(height: 8),
          _buildToggleButton(),
        ],
      ),
    );
  }

  Widget _buildSortingRow() {
    final sortState = ref.watch(sortStateProvider);
    final sortOption = sortState.option;
    final sortAscending = sortState.ascending;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<SortOption>(
            value: sortOption,
            decoration: InputDecoration(
              labelText: 'Sort by',
              isDense: true,
              filled: true,
              fillColor: AppTheme.backgroundDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            items: SortOption.values.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(_getSortLabel(option)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                // For PageSpeed, start with ascending (lowest scores first)
                final newAscending = value == SortOption.pageSpeed ? true : sortAscending;
                ref.read(currentSortStateProvider.notifier).updateSort(value, newAscending);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            color: AppTheme.primaryGold,
          ),
          onPressed: () {
            ref.read(currentSortStateProvider.notifier).updateSort(sortState.option, !sortAscending);
          },
          tooltip: sortAscending ? 'Ascending' : 'Descending',
        ),
      ],
    );
  }

  Widget _buildQuickFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip('Has Website', ref.watch(hasWebsiteFilterProvider) == true,
            (selected) => ref.read(currentFilterStateProvider.notifier).updateHasWebsiteFilter(selected ? true : null)),
        _buildFilterChip('No Website', ref.watch(hasWebsiteFilterProvider) == false,
            (selected) => ref.read(currentFilterStateProvider.notifier).updateHasWebsiteFilter(selected ? false : null)),
        _buildFilterChip('High Rating', ref.watch(meetsRatingFilterProvider) == true,
            (selected) => ref.read(currentFilterStateProvider.notifier).updateMeetsRatingFilter(selected ? true : null)),
        _buildFilterChip('Recent Reviews', ref.watch(hasRecentReviewsFilterProvider) == true,
            (selected) => ref.read(currentFilterStateProvider.notifier).updateHasRecentReviewsFilter(selected ? true : null)),
      ],
    );
  }

  String _getSortLabel(SortOption option) => option.name.replaceAll('_', ' ').toUpperCase();

  Widget _buildFilterChip(String label, bool selected, Function(bool) onSelected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppTheme.primaryGold.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primaryGold,
    );
  }

  Widget _buildAdvancedFilterSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Filters',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          // Add more advanced filter options here
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('Candidates Only', ref.watch(candidatesOnlyProvider),
                  (selected) => ref.read(currentFilterStateProvider.notifier).updateCandidatesOnly(selected)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    return GestureDetector(
      onTap: () => setState(() => showAdvancedFilters = !showAdvancedFilters),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              showAdvancedFilters ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              showAdvancedFilters ? 'Hide Advanced' : 'Show Advanced',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}