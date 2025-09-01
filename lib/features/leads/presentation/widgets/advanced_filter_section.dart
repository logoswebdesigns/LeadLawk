import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../pages/leads_list_page.dart';
import 'advanced_filter_bar.dart';
import 'advanced_filter_extras.dart';

extension AdvancedFilterBarExtension on AdvancedFilterBarState {
  Widget buildAdvancedFilterSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildRatingFilter()),
            const SizedBox(width: 8),
            Expanded(child: _buildReviewCountFilter()),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildPageSpeedFilter()),
            const SizedBox(width: 8),
            Expanded(child: buildFollowUpFilter()),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: buildLocationFilter()),
            const SizedBox(width: 8),
            Expanded(child: buildIndustryFilter()),
          ],
        ),
        const SizedBox(height: 8),
        buildGroupBySection(),
      ],
    );
  }

  Widget _buildRatingFilter() {
    final value = ref.watch(ratingRangeFilterProvider);
    return DropdownButtonFormField<String?>(
      value: value,
      decoration: _getInputDecoration('Rating Range'),
      items: const [
        DropdownMenuItem(value: null, child: Text('All Ratings')),
        DropdownMenuItem(value: '5', child: Text('5 Stars')),
        DropdownMenuItem(value: '4-5', child: Text('4-5 Stars')),
        DropdownMenuItem(value: '3-4', child: Text('3-4 Stars')),
        DropdownMenuItem(value: '2-3', child: Text('2-3 Stars')),
        DropdownMenuItem(value: '1-2', child: Text('1-2 Stars')),
      ],
      onChanged: (value) => ref.read(ratingRangeFilterProvider.notifier).state = value,
    );
  }

  Widget _buildReviewCountFilter() {
    final value = ref.watch(reviewCountRangeFilterProvider);
    return DropdownButtonFormField<String?>(
      value: value,
      decoration: _getInputDecoration('Review Count'),
      items: const [
        DropdownMenuItem(value: null, child: Text('All Reviews')),
        DropdownMenuItem(value: '100+', child: Text('100+ Reviews')),
        DropdownMenuItem(value: '50-99', child: Text('50-99 Reviews')),
        DropdownMenuItem(value: '20-49', child: Text('20-49 Reviews')),
        DropdownMenuItem(value: '5-19', child: Text('5-19 Reviews')),
        DropdownMenuItem(value: '1-4', child: Text('1-4 Reviews')),
      ],
      onChanged: (value) => ref.read(reviewCountRangeFilterProvider.notifier).state = value,
    );
  }

  Widget _buildPageSpeedFilter() {
    final value = ref.watch(pageSpeedFilterProvider);
    return DropdownButtonFormField<String?>(
      value: value,
      decoration: _getInputDecoration('PageSpeed Score'),
      items: const [
        DropdownMenuItem(value: null, child: Text('All Scores')),
        DropdownMenuItem(value: '90+', child: Text('90+ (Fast)')),
        DropdownMenuItem(value: '50-89', child: Text('50-89 (Average)')),
        DropdownMenuItem(value: '<50', child: Text('<50 (Slow)')),
        DropdownMenuItem(value: 'none', child: Text('Not Analyzed')),
      ],
      onChanged: (value) => ref.read(pageSpeedFilterProvider.notifier).state = value,
    );
  }

  Widget buildToggleButton() {
    return TextButton.icon(
      onPressed: () => setState(() => showAdvancedFilters = !showAdvancedFilters),
      icon: Icon(showAdvancedFilters ? Icons.expand_less : Icons.expand_more),
      label: Text(showAdvancedFilters ? 'Hide Advanced Filters' : 'Show Advanced Filters'),
      style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGold),
    );
  }

  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: AppTheme.backgroundDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }
}