import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/providers/filter_providers.dart';
import '../../domain/entities/lead.dart';
import 'advanced_filter_bar.dart';

extension AdvancedFilterSearchExtension on AdvancedFilterBarState {
  Widget buildSearchBar() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Search leads by name, phone, location, or industry...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  searchController.clear();
                  ref.read(currentFilterStateProvider.notifier).updateSearchFilter('');
                },
              )
            : null,
        filled: true,
        fillColor: AppTheme.backgroundDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (value) {
        debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            ref.read(currentFilterStateProvider.notifier).updateSearchFilter(value);
          }
        });
      },
    );
  }

  Widget buildStatusFilters() {
    final currentStatus = ref.watch(statusFilterProvider);
    final candidatesOnly = ref.watch(candidatesOnlyProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Status Filter:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.mediumGray,
              ),
            ),
            const SizedBox(width: 12),
            FilterChip(
              label: const Text('Candidates Only'),
              selected: candidatesOnly,
              onSelected: (value) => ref.read(currentFilterStateProvider.notifier).updateCandidatesOnly(value),
              selectedColor: AppTheme.primaryGold.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.primaryGold,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: LeadStatus.values.map((status) {
              final label = _getStatusLabel(status);
              final isSelected = currentStatus == label.toLowerCase();
              
              return Padding(padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    ref.read(currentFilterStateProvider.notifier).updateStatusFilter(
                      selected ? status.name : null);
                  },
                  selectedColor: _getStatusColor(status).withValues(alpha: 0.2),
                  checkmarkColor: _getStatusColor(status),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(LeadStatus status) => 
    status == LeadStatus.new_ ? AppTheme.mediumGray :
    status == LeadStatus.viewed ? AppTheme.darkGray :
    status == LeadStatus.called ? AppTheme.warningOrange :
    status == LeadStatus.interested ? AppTheme.primaryBlue :
    status == LeadStatus.converted ? AppTheme.successGreen :
    status == LeadStatus.didNotConvert ? Colors.deepOrange :
    status == LeadStatus.callbackScheduled ? AppTheme.primaryBlue :
    AppTheme.errorRed;

  String _getStatusLabel(LeadStatus status) =>
    status == LeadStatus.new_ ? 'NEW' :
    status == LeadStatus.viewed ? 'VIEWED' :
    status == LeadStatus.called ? 'CALLED' :
    status == LeadStatus.interested ? 'INTERESTED' :
    status == LeadStatus.converted ? 'CONVERTED' :
    status == LeadStatus.didNotConvert ? 'NO CONVERT' :
    status == LeadStatus.callbackScheduled ? 'CALLBACK' : 'DNC';
}