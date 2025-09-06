import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/paginated_leads_provider.dart';
import '../../domain/providers/filter_providers.dart';

class StatusFilterModal extends ConsumerStatefulWidget {
  const StatusFilterModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => const StatusFilterModal(),
    );
  }

  @override
  ConsumerState<StatusFilterModal> createState() => _StatusFilterModalState();
}

class _StatusFilterModalState extends ConsumerState<StatusFilterModal> {
  late Set<String> tempHiddenStatuses;
  
  @override
  void initState() {
    super.initState();
    // Initialize with current hidden statuses
    tempHiddenStatuses = Set.from(ref.read(hiddenStatusesProvider));
  }

  @override
  Widget build(BuildContext context) {
    const allStatuses = LeadStatus.values;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                CupertinoIcons.eye_slash,
                color: AppTheme.primaryGold,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Filter Statuses',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hide leads with these statuses:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          
          // Quick actions
          Row(
            children: [
              _buildQuickAction(
                'Show All',
                () => setState(() => tempHiddenStatuses.clear()),
              ),
              const SizedBox(width: 8),
              _buildQuickAction(
                'Hide All',
                () => setState(() => 
                  tempHiddenStatuses = allStatuses.map((s) => s.name).toSet()),
              ),
              const SizedBox(width: 8),
              _buildQuickAction(
                'Hide Processed',
                () => setState(() {
                  tempHiddenStatuses = {
                    LeadStatus.called.name,
                    LeadStatus.converted.name,
                    LeadStatus.didNotConvert.name,
                    LeadStatus.doNotCall.name,
                  };
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Status list
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allStatuses.length,
              itemBuilder: (context, index) {
                final status = allStatuses[index];
                final isHidden = tempHiddenStatuses.contains(status.name);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.elevatedSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isHidden 
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: CheckboxListTile(
                    title: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _getStatusLabel(status),
                          style: TextStyle(
                            color: isHidden 
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: isHidden 
                              ? TextDecoration.lineThrough 
                              : null,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      _getStatusDescription(status),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    value: !isHidden, // Checkbox shows visible state
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          tempHiddenStatuses.remove(status.name);
                        } else {
                          tempHiddenStatuses.add(status.name);
                        }
                      });
                    },
                    activeColor: AppTheme.primaryGold,
                    checkColor: Colors.black,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Apply the filter through domain provider
                // Note: Need to update filter state with new hidden statuses
                // This would require accessing the currentFilterStateProvider.notifier
                
                // Trigger refresh to apply the new filter
                ref.read(paginatedLeadsProvider.notifier).refreshLeads();
                
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                tempHiddenStatuses.isEmpty 
                  ? 'Show All Statuses'
                  : 'Apply Filter (${tempHiddenStatuses.length} hidden)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryGold,
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
      case LeadStatus.interested: return 'Interested';
      case LeadStatus.converted: return 'Converted';
      case LeadStatus.didNotConvert: return 'Did Not Convert';
      case LeadStatus.callbackScheduled: return 'Callback Scheduled';
      case LeadStatus.doNotCall: return 'Do Not Call';
    }
  }

  String _getStatusDescription(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_: return 'Fresh leads not yet viewed';
      case LeadStatus.viewed: return 'Leads you have looked at';
      case LeadStatus.called: return 'Leads you have contacted';
      case LeadStatus.interested: return 'Leads showing interest';
      case LeadStatus.converted: return 'Successfully converted leads';
      case LeadStatus.didNotConvert: return 'Leads that did not convert';
      case LeadStatus.callbackScheduled: return 'Scheduled for follow-up';
      case LeadStatus.doNotCall: return 'Should not be contacted';
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