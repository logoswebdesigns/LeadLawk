import 'package:flutter/material.dart';
import '../../domain/providers/filter_providers.dart' as domain_filters;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';

class PrimaryFilterRow extends ConsumerWidget {
  const PrimaryFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStatus = ref.watch(domain_filters.statusFilterProvider);
    final searchFilter = ref.watch(domain_filters.searchFilterProvider);
    
    return Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Search filter chip (if active)
            if (searchFilter.isNotEmpty) ...[
              _buildSearchChip(searchFilter, ref),
              const SizedBox(width: 8),
            ],
            _buildStatusChip('All', null, currentStatus, ref),
            ...LeadStatus.values.map((status) {
              final label = _getStatusLabel(status);
              return _buildStatusChip(
                label,
                status.name,
                currentStatus,
                ref,
                color: _getStatusColor(status),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchChip(String searchTerm, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryGold.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 14,
            color: AppTheme.primaryGold,
          ),
          const SizedBox(width: 6),
          Text(
            '"$searchTerm"',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGold,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              ref.read(domain_filters.currentFilterStateProvider.notifier).updateSearchFilter('');
            },
            child: Icon(
              Icons.close,
              size: 14,
              color: AppTheme.primaryGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    String label,
    String? value,
    String? currentValue,
    WidgetRef ref,
    {Color? color}
  ) {
    final isSelected = currentValue == value;
    
    return Padding(padding: EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          ref.read(domain_filters.currentFilterStateProvider.notifier).updateStatusFilter(value);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? (color ?? AppTheme.primaryGold).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? (color ?? AppTheme.primaryGold).withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? (color ?? AppTheme.primaryGold)
                  : Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusLabel(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_: return 'New';
      case LeadStatus.viewed: return 'Viewed';
      case LeadStatus.called: return 'Called';
      case LeadStatus.interested: return 'Interest';
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
}