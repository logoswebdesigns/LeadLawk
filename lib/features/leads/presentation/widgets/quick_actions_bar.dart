import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/job_provider.dart';
import 'email_template_dialog.dart';
import 'callback_scheduling_dialog.dart';
import 'lead_status_actions.dart';

class QuickActionsBar extends ConsumerWidget {
  final Lead lead;
  final VoidCallback? onRefresh;
  final VoidCallback? onNavigateNext;

  const QuickActionsBar({
    super.key,
    required this.lead,
    this.onRefresh,
    this.onNavigateNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildActionButton(
                    context: context,
                    icon: Icons.block,
                    label: 'Mark DNC',
                    color: Colors.red,
                    onPressed: lead.status == LeadStatus.doNotCall
                        ? null
                        : () => _handleDNC(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    context: context,
                    icon: Icons.cancel,
                    label: 'Did Not Convert',
                    color: Colors.deepOrange,
                    onPressed: lead.status == LeadStatus.didNotConvert
                        ? null
                        : () => _handleDidNotConvert(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    context: context,
                    icon: Icons.check_circle,
                    label: 'Converted',
                    color: Colors.blue,
                    onPressed: lead.status == LeadStatus.converted
                        ? null
                        : () => _handleConverted(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    context: context,
                    icon: Icons.star,
                    label: 'Interested',
                    color: Colors.amber,
                    onPressed: lead.status == LeadStatus.interested
                        ? null
                        : () => _handleInterested(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    context: context,
                    icon: Icons.schedule,
                    label: 'Follow-up',
                    color: Colors.purple,
                    onPressed: () => _handleFollowUp(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    context: context,
                    icon: Icons.email,
                    label: 'Email',
                    color: Colors.teal,
                    onPressed: () => _handleEmail(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    context: context,
                    icon: Icons.map,
                    label: 'View on Maps',
                    color: Colors.indigo,
                    onPressed: () => _handleViewOnMaps(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;
    
    return Material(
      color: isEnabled 
          ? color.withValues(alpha: 0.1)
          : Theme.of(context).disabledColor.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isEnabled ? color : Theme.of(context).disabledColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isEnabled ? color : Theme.of(context).disabledColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDidNotConvert(BuildContext context, WidgetRef ref) async {
    ConversionFailureReason? selectedReason;
    String additionalNotes = '';
    
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.elevatedSurface,
          title: const Text(
            'Mark as Did Not Convert',
            style: TextStyle(color: AppTheme.warningOrange),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a reason why ${lead.businessName} did not convert:',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ConversionFailureReason>(
                  value: selectedReason,
                  decoration: InputDecoration(
                    labelText: 'Reason Code *',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                  ),
                  dropdownColor: AppTheme.elevatedSurface,
                  items: ConversionFailureReason.values.map((reason) => DropdownMenuItem(
                    value: reason,
                    child: Text(
                      '${reason.label} (${reason.code})',
                      style: const TextStyle(color: Colors.white),
                    ),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: additionalNotes,
                  onChanged: (value) {
                    additionalNotes = value;
                  },
                  decoration: InputDecoration(
                    labelText: 'Additional Notes (Optional)',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedReason != null ? () {
                Navigator.of(context).pop({
                  'reason': selectedReason,
                  'notes': additionalNotes,
                });
              } : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.warningOrange,
              ),
              child: const Text('Mark Did Not Convert'),
            ),
          ],
        ),
      ),
    );
    
    if (result != null && result['reason'] != null) {
      final repository = ref.read(leadsRepositoryProvider);
      final reason = result['reason'] as ConversionFailureReason;
      
      // Update the lead with status and conversion failure details
      final updatedLead = lead.copyWith(
        status: LeadStatus.didNotConvert,
        conversionFailureReason: reason.code,
        conversionFailureNotes: result['notes'] as String?,
        conversionFailureDate: DateTime.now(),
      );
      await repository.updateLead(updatedLead);
      
      // Add timeline entry with reason code
      await repository.addTimelineEntry(lead.id, {
        'type': 'STATUS_CHANGE',
        'title': 'Status changed to DID NOT CONVERT',
        'description': result['notes'] ?? '',
        'metadata': {
          'reason': reason.label,
          'reason_code': reason.code,
          'notes': result['notes'],
        },
      });
      
      onRefresh?.call();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lead.businessName} marked as Did Not Convert - ${reason.label}'),
            backgroundColor: AppTheme.warningOrange,
          ),
        );
        
        // Add a small delay before navigation to ensure UI updates complete
        await Future.delayed(Duration(milliseconds: 100));
        
        // Navigate to next lead after successful submission
        if (context.mounted) {
          onNavigateNext?.call();
        }
      }
    }
  }

  Future<void> _handleDNC(BuildContext context, WidgetRef ref) async {
    // TODO: Add reason code dialog for doNotCall status
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Do Not Call'),
        content: Text('Are you sure you want to mark ${lead.businessName} as Do Not Call?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Mark DNC'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repository = ref.read(leadsRepositoryProvider);
      final updatedLead = lead.copyWith(status: LeadStatus.doNotCall);
      await repository.updateLead(updatedLead);
      
      // Add timeline entry with reason code (to be implemented)
      await repository.addTimelineEntry(lead.id, {
        'type': 'STATUS_CHANGE',
        'content': 'Status changed to Do Not Call',
        'metadata': {'reason': 'user_requested'}, // Placeholder for reason code
      });
      
      onRefresh?.call();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lead.businessName} marked as Do Not Call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleConverted(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(leadsRepositoryProvider);
    final updatedLead = lead.copyWith(status: LeadStatus.converted);
    await repository.updateLead(updatedLead);
    
    // Add timeline entry
    await repository.addTimelineEntry(lead.id, {
      'type': 'STATUS_CHANGE',
      'content': 'Lead converted successfully! 🎉',
    });
    
    onRefresh?.call();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${lead.businessName} marked as Converted! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleInterested(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(leadsRepositoryProvider);
    final updatedLead = lead.copyWith(status: LeadStatus.interested);
    await repository.updateLead(updatedLead);
    
    // Add timeline entry
    await repository.addTimelineEntry(lead.id, {
      'type': 'STATUS_CHANGE',
      'content': 'Lead marked as interested',
    });
    
    onRefresh?.call();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${lead.businessName} marked as Interested'),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }

  Future<void> _handleFollowUp(BuildContext context, WidgetRef ref) async {
    // Use the enhanced callback scheduling dialog with calendar invite options
    await showDialog(
      context: context,
      builder: (context) => CallbackSchedulingDialog(lead: lead),
    );
    
    // The dialog handles everything including timeline entries and notifications
    onRefresh?.call();
  }

  Future<void> _handleEmail(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (context) => EmailTemplateDialog(lead: lead),
    );
  }

  Future<void> _handleViewOnMaps(BuildContext context, WidgetRef ref) async {
    // TODO: Implement open in Google Maps
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening in Google Maps...'),
        backgroundColor: Colors.indigo,
      ),
    );
  }
}