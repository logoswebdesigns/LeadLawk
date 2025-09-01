import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../pages/leads_list_page.dart';

class PrimaryFilterRow extends ConsumerWidget {
  const PrimaryFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStatus = ref.watch(statusFilterProvider);
    
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
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

  Widget _buildStatusChip(
    String label,
    String? value,
    String? currentValue,
    WidgetRef ref,
    {Color? color}
  ) {
    final isSelected = currentValue == value;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          ref.read(statusFilterProvider.notifier).state = value;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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