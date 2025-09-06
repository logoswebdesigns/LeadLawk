import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/providers/filter_providers.dart';

class AdvancedFilterSection extends ConsumerWidget {
  const AdvancedFilterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),
          Text(
            'FILTERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          // Quick Filters
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickFilter('Called Today', ref.watch(calledTodayProvider),
                  (val) => ref.read(currentFilterStateProvider.notifier).updateCalledToday(val), ref,
                  icon: Icons.phone_in_talk),
              _buildQuickFilter('Has Website', ref.watch(hasWebsiteFilterProvider) == true,
                  (val) => ref.read(currentFilterStateProvider.notifier).updateHasWebsiteFilter(val ? true : null), ref),
              _buildQuickFilter('No Website', ref.watch(hasWebsiteFilterProvider) == false,
                  (val) => ref.read(currentFilterStateProvider.notifier).updateHasWebsiteFilter(val ? false : null), ref),
              _buildQuickFilter('High Rating', ref.watch(meetsRatingFilterProvider) == true,
                  (val) => ref.read(currentFilterStateProvider.notifier).updateMeetsRatingFilter(val ? true : null), ref),
              _buildQuickFilter('Recent Reviews', ref.watch(hasRecentReviewsFilterProvider) == true,
                  (val) => ref.read(currentFilterStateProvider.notifier).updateHasRecentReviewsFilter(val ? true : null), ref),
            ],
          ),
          const SizedBox(height: 16),
          // Dropdown Filters
          Row(
            children: [
              Expanded(child: _buildDropdown('Rating', ref.watch(ratingRangeFilterProvider), _ratingOptions(), 
                  (val) => ref.read(currentFilterStateProvider.notifier).updateRatingRangeFilter(val))),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown('Reviews', ref.watch(reviewCountRangeFilterProvider), _reviewOptions(),
                  (val) => ref.read(currentFilterStateProvider.notifier).updateReviewCountRangeFilter(val))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDropdown('PageSpeed', ref.watch(pageSpeedFilterProvider), _speedOptions(),
                  (val) => ref.read(currentFilterStateProvider.notifier).updatePageSpeedFilter(val))),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown('Follow-up', ref.watch(followUpFilterProvider), _followUpOptions(),
                  (val) => ref.read(currentFilterStateProvider.notifier).updateFollowUpFilter(val))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilter(String label, bool isSelected, Function(bool) onTap, WidgetRef ref, {IconData? icon}) {
    return GestureDetector(
      onTap: () => onTap(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryGold.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryGold.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? AppTheme.primaryGold
                    : Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppTheme.primaryGold
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<DropdownOption> options, Function(String?) onChanged) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          hint: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          icon: Icon(
            CupertinoIcons.chevron_down,
            size: 16,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          dropdownColor: AppTheme.elevatedSurface,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
          ),
          items: options.map((opt) => DropdownMenuItem(
            value: opt.value,
            child: Text(opt.label),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<DropdownOption> _ratingOptions() => [
    DropdownOption(null, 'All Ratings'),
    DropdownOption('5', '5 Stars'),
    DropdownOption('4-5', '4-5 Stars'),
    DropdownOption('3-4', '3-4 Stars'),
  ];

  List<DropdownOption> _reviewOptions() => [
    DropdownOption(null, 'All Reviews'),
    DropdownOption('100+', '100+'),
    DropdownOption('50-99', '50-99'),
    DropdownOption('20-49', '20-49'),
  ];

  List<DropdownOption> _speedOptions() => [
    DropdownOption(null, 'All Speeds'),
    DropdownOption('90+', 'Fast (90+)'),
    DropdownOption('50-89', 'Average'),
    DropdownOption('<50', 'Slow (<50)'),
  ];

  List<DropdownOption> _followUpOptions() => [
    DropdownOption(null, 'All'),
    DropdownOption('upcoming', 'Upcoming'),
    DropdownOption('overdue', 'Overdue'),
  ];
}

class DropdownOption {
  final String? value;
  final String label;
  DropdownOption(this.value, this.label);
}