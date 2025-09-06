import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'advanced_filter_bar.dart';
import '../../domain/providers/filter_providers.dart';
import '../../domain/entities/filter_state.dart';

extension AdvancedFilterExtrasExtension on AdvancedFilterBarState {
  Widget buildFollowUpFilter() {
    final value = ref.watch(followUpFilterProvider);
    return DropdownButtonFormField<String?>(
      value: value,
      decoration: _getInputDecoration('Follow-up Status'),
      items: const [
        DropdownMenuItem(value: null, child: const Text('All Follow-ups')),
        DropdownMenuItem(value: 'upcoming', child: const Text('Upcoming')),
        DropdownMenuItem(value: 'overdue', child: const Text('Overdue')),
      ],
      onChanged: (value) => ref.read(currentFilterStateProvider.notifier).updateFollowUpFilter(value),
    );
  }

  Widget buildLocationFilter() {
    final value = ref.watch(locationFilterProvider);
    return TextFormField(
      initialValue: value,
      decoration: _getInputDecoration('Location'),
      onChanged: (value) {
        ref.read(currentFilterStateProvider.notifier).updateLocationFilter(value.isEmpty ? null : value);
      },
    );
  }

  Widget buildIndustryFilter() {
    final value = ref.watch(industryFilterProvider);
    return TextFormField(
      initialValue: value,
      decoration: _getInputDecoration('Industry'),
      onChanged: (value) {
        ref.read(currentFilterStateProvider.notifier).updateIndustryFilter(value.isEmpty ? null : value);
      },
    );
  }

  Widget buildGroupBySection() {
    final groupBy = ref.watch(groupByOptionProvider);
    
    return Row(
      children: [
        const Text('Group by:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: GroupByOption.values.map((option) {
              return ChoiceChip(
                label: Text(_getGroupByLabel(option)),
                selected: groupBy == option,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(currentUIStateProvider.notifier).updateGroupByOption(option);
                    // Groups are cleared automatically when groupByOption changes
                  }
                },
                selectedColor: AppTheme.primaryGold.withValues(alpha: 0.2),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getGroupByLabel(GroupByOption option) {
    switch (option) {
      case GroupByOption.none:
        return 'None';
      case GroupByOption.status:
        return 'Status';
      case GroupByOption.location:
        return 'Location';
      case GroupByOption.industry:
        return 'Industry';
      case GroupByOption.hasWebsite:
        return 'Website';
      case GroupByOption.pageSpeed:
        return 'PageSpeed';
      case GroupByOption.rating:
        return 'Rating';
    }
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