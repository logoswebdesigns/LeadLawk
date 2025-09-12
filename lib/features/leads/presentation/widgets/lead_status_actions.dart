import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/lead_detail_provider.dart';
import '../providers/job_provider.dart' show leadsRepositoryProvider;
import '../providers/goals_provider.dart';
import '../providers/use_case_providers.dart';
import '../providers/command_provider.dart';
import '../services/unified_call_service.dart';
import 'callback_scheduling_dialog.dart';


// Did Not Convert reason codes
enum ConversionFailureReason {
  notInterested('Not Interested', 'NI'),
  tooExpensive('Too Expensive', 'TE'),
  competitor('Using Competitor', 'COMP'),
  badTiming('Bad Timing', 'BT'),
  tooSmall('Business Too Small', 'TS'),
  tooBig('Business Too Big', 'TB'),
  badFit('Not Good Fit', 'NGF'),
  noDecisionMaker('No Decision Maker', 'NDM'),
  noBudget('No Budget', 'NB'),
  longSalesCycle('Long Sales Cycle', 'LSC'),
  lostContact('Lost Contact', 'LC'),
  other('Other Reason', 'OTH');

  final String label;
  final String code;
  const ConversionFailureReason(this.label, this.code);
}

// Call outcomes
enum CallOutcome {
  answered('Answered'),
  voicemail('Voicemail'),
  noAnswer('No Answer'),
  busy('Busy'),
  disconnected('Disconnected'),
  wrongNumber('Wrong Number');

  final String label;
  const CallOutcome(this.label);
}

class LeadStatusActions extends ConsumerStatefulWidget {
  final Lead lead;
  
  const LeadStatusActions({
    super.key,
    required this.lead,
  });

  @override
  ConsumerState<LeadStatusActions> createState() => _LeadStatusActionsState();
}

class _LeadStatusActionsState extends ConsumerState<LeadStatusActions> {
  bool _isExpanded = false;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(LeadStatus newStatus, {Map<String, dynamic>? metadata}) async {
    try {
      // Validate the transition using pipeline use case
      final pipeline = ref.read(manageLeadPipelineProvider);
      final validationResult = pipeline.validateTransition(widget.lead.status, newStatus);
      
      if (validationResult.isLeft()) {
        // Show error if transition is invalid
        validationResult.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          ),
          (_) {},
        );
        return;
      }
      
      // Prepare update data
      final updateData = <String, dynamic>{'status': newStatus};
      
      // Check if this is a "did not convert" with "too_big" reason - should be blacklisted
      if (newStatus == LeadStatus.didNotConvert && metadata != null) {
        final reasonCode = metadata['reason_code'];
        print('🔍 DID NOT CONVERT: reasonCode = $reasonCode, metadata = $metadata');
        if (reasonCode == 'TB') {  // TB = Too Big
          updateData['addToBlacklist'] = true;
          updateData['blacklistReason'] = 'too_big';
          print('🚫 AUTO-BLACKLIST: Marking ${widget.lead.businessName} as too_big for blacklist');
        }
        // Store the reason in the lead's metadata
        updateData['conversionFailureReason'] = reasonCode;
        updateData['conversionFailureNotes'] = metadata['notes'];
      }
      
      print('📤 Sending update data: $updateData');
      print('📤 Status: $newStatus, Metadata: $metadata');
      
      // Use command pattern for update
      final updateCommand = ref.read(updateLeadCommandProvider);
      final result = await updateCommand(widget.lead, updateData);
      
      if (result.isLeft()) {
        result.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update status: ${failure.message}')),
          ),
          (_) {},
        );
        return;
      }
      
      // Add timeline entry separately (still using repository for now)
      final repository = ref.read(leadsRepositoryProvider);
      final timelineData = {
        'type': 'STATUS_CHANGE',
        'title': 'Status changed to ${_getStatusLabel(newStatus)}',
        'description': metadata?['notes'] ?? '',
        'metadata': metadata,
      };
      
      // Add timeline entry
      await repository.addTimelineEntry(widget.lead.id, timelineData);
      
      // Refresh the lead details
      ref.invalidate(leadDetailProvider(widget.lead.id));
      
      // Refresh goals metrics when status changes (especially for CALLED status)
      if (newStatus == LeadStatus.called || newStatus == LeadStatus.converted) {
        ref.read(goalsProvider.notifier).refreshMetrics();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${_getStatusLabel(newStatus)}'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _makeCall() async {
    await UnifiedCallService.handleCall(
      context: context,
      ref: ref,
      lead: widget.lead,
      onComplete: () {
        // Refresh the lead details
        ref.invalidate(leadDetailProvider(widget.lead.id));
      },
    );
  }


  Future<void> _showDoNotCallDialog() async {
    final reasonController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.elevatedSurface,
        title: const Text(
          'Mark as Do Not Call',
          style: TextStyle(color: AppTheme.errorRed),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will mark the lead as Do Not Call.',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Reason (Optional)',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                hintText: 'Enter reason if needed...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(LeadStatus.doNotCall, metadata: {
                'reason': reasonController.text.isNotEmpty ? reasonController.text : 'User requested',
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Do Not Call'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDidNotConvertDialog() async {
    ConversionFailureReason? selectedReason;
    final reasonController = TextEditingController();
    final dropdownKey = GlobalKey<FormFieldState>();
    
    await showDialog(
      context: context,
      builder: (context) {
        // Schedule the dropdown to open after the dialog is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Simulate a tap on the dropdown to open it
          final RenderBox? dropdown = dropdownKey.currentContext?.findRenderObject() as RenderBox?;
          if (dropdown != null) {
            final Offset localPosition = Offset(dropdown.size.width / 2, dropdown.size.height / 2);
            final Offset globalPosition = dropdown.localToGlobal(localPosition);
            
            GestureBinding.instance.handlePointerEvent(
              PointerDownEvent(
                position: globalPosition,
                kind: PointerDeviceKind.touch,
              ),
            );
            GestureBinding.instance.handlePointerEvent(
              PointerUpEvent(
                position: globalPosition,
                kind: PointerDeviceKind.touch,
              ),
            );
          }
        });
        
        return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.elevatedSurface,
          title: const Text(
            'Mark as Did Not Convert',
            style: TextStyle(color: AppTheme.warningOrange),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please select a reason for non-conversion:',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ConversionFailureReason>(
                key: dropdownKey,
                autofocus: true,
                value: selectedReason,
                decoration: const InputDecoration(
                  labelText: 'Reason Code',
                  border: OutlineInputBorder(),
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
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Additional Notes',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  hintText: 'Enter any additional details...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedReason != null ? () {
                Navigator.pop(context);
                _updateStatus(LeadStatus.didNotConvert, metadata: {
                  'reason': selectedReason!.label,
                  'reason_code': selectedReason!.code,
                  'notes': reasonController.text,
                });
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Mark Did Not Convert'),
            ),
          ],
        ),
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use pipeline use case to get available transitions
    final availableTransitions = ref.watch(availableTransitionsProvider(widget.lead.status));
    // final pipelineProgress = ref.watch(pipelineProgressProvider(widget.lead.status));
    
    final isTerminalStatus = availableTransitions.isEmpty;
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGold.withValues(alpha: 0.1),
            AppTheme.primaryBlue.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGold.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              onTap: !isTerminalStatus ? () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              } : null,
              child: Padding(padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(widget.lead.status).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getStatusIcon(widget.lead.status),
                        color: _getStatusColor(widget.lead.status),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Status',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _getStatusLabel(widget.lead.status),
                          style: TextStyle(
                            color: _getStatusColor(widget.lead.status),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (!isTerminalStatus)
                      AnimatedRotation(
                        duration: Duration(milliseconds: 200),
                        turns: _isExpanded ? 0.5 : 0.0,
                        child: Icon(
                          Icons.expand_more,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          // Actions
          if (!isTerminalStatus)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: _isExpanded ? null : 0,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 200),
                opacity: _isExpanded ? 1.0 : 0.0,
                child: _isExpanded ? Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 12),
                      
                      // Quick actions based on current status
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Call button (special handling)
                      if (widget.lead.phone.isNotEmpty) ...[
                        _buildActionButton(
                          icon: Icons.phone,
                          label: 'Call Lead',
                          color: AppTheme.primaryBlue,
                          onTap: _makeCall,
                          isProminent: true,
                        ),
                        const SizedBox(height: 8),
                      ],
                      
                      // Status progression buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildStatusActions(),
                      ),
                      
                      // Terminal status buttons (always available)
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.block,
                              label: 'Do Not Call',
                              color: AppTheme.errorRed,
                              onTap: _showDoNotCallDialog,
                              isDanger: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.close,
                              label: 'Did Not Convert',
                              color: AppTheme.warningOrange,
                              onTap: _showDidNotConvertDialog,
                              isDanger: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ) : SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildStatusActions() {
    final actions = <Widget>[];
    
    switch (widget.lead.status) {
      case LeadStatus.new_:
        actions.add(_buildStatusChip(LeadStatus.viewed, 'Mark Viewed'));
        break;
      
      case LeadStatus.viewed:
        // Don't show direct 'Mark Called' - force through phone call flow
        break;
      
      case LeadStatus.called:
        actions.add(_buildStatusChip(LeadStatus.interested, 'Mark Interested'));
        actions.add(_buildStatusChip(LeadStatus.converted, 'Mark Converted'));
        actions.add(_buildCallbackChip());
        break;
      
      case LeadStatus.callbackScheduled:
        actions.add(_buildStatusChip(LeadStatus.interested, 'Mark Interested'));
        actions.add(_buildStatusChip(LeadStatus.called, 'Back to Called'));
        break;
      
      case LeadStatus.interested:
        actions.add(_buildStatusChip(LeadStatus.converted, 'Mark Converted'));
        actions.add(_buildStatusChip(LeadStatus.called, 'Back to Called'));
        break;
      
      case LeadStatus.converted:
      case LeadStatus.doNotCall:
      case LeadStatus.didNotConvert:
        // Terminal statuses - no progression
        break;
    }
    
    return actions;
  }

  Widget _buildStatusChip(LeadStatus status, String label) {
    return ActionChip(
      avatar: Icon(
        _getStatusIcon(status),
        size: 16,
        color: _getStatusColor(status),
      ),
      label: Text(label),
      onPressed: () => _updateStatus(status),
      backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: _getStatusColor(status),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: _getStatusColor(status).withValues(alpha: 0.4),
        width: 1,
      ),
    );
  }
  
  Widget _buildCallbackChip() {
    return ActionChip(
      avatar: Icon(
        Icons.event,
        size: 16,
        color: Colors.purple,
      ),
      label: const Text('Schedule Callback'),
      onPressed: () async {
        await showDialog(
          context: context,
          builder: (context) => CallbackSchedulingDialog(lead: widget.lead),
        );
      },
      backgroundColor: Colors.purple.withValues(alpha: 0.2),
      labelStyle: const TextStyle(
        color: Colors.purple,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: Colors.purple.withValues(alpha: 0.4),
        width: 1,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isProminent = false,
    bool isDanger = false,
  }) {
    return Material(
      color: isProminent ? color : (isDanger ? color.withValues(alpha: 0.1) : Colors.transparent),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: isDanger ? 0.5 : 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isProminent ? Colors.white : color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isProminent ? Colors.white : color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return AppTheme.mediumGray;
      case LeadStatus.viewed:
        return Colors.blueGrey;
      case LeadStatus.called:
        return AppTheme.warningOrange;
      case LeadStatus.callbackScheduled:
        return Colors.purple;
      case LeadStatus.interested:
        return AppTheme.primaryBlue;
      case LeadStatus.converted:
        return AppTheme.successGreen;
      case LeadStatus.doNotCall:
        return AppTheme.errorRed;
      case LeadStatus.didNotConvert:
        return Colors.deepOrange;
    }
  }

  IconData _getStatusIcon(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return Icons.fiber_new;
      case LeadStatus.viewed:
        return Icons.visibility;
      case LeadStatus.called:
        return Icons.phone_in_talk;
      case LeadStatus.callbackScheduled:
        return Icons.event;
      case LeadStatus.interested:
        return Icons.star;
      case LeadStatus.converted:
        return Icons.check_circle;
      case LeadStatus.doNotCall:
        return Icons.phone_disabled;
      case LeadStatus.didNotConvert:
        return Icons.cancel;
    }
  }

  String _getStatusLabel(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return 'NEW';
      case LeadStatus.viewed:
        return 'VIEWED';
      case LeadStatus.called:
        return 'CALLED';
      case LeadStatus.callbackScheduled:
        return 'CALLBACK SCHEDULED';
      case LeadStatus.interested:
        return 'INTERESTED';
      case LeadStatus.converted:
        return 'CONVERTED';
      case LeadStatus.doNotCall:
        return 'DO NOT CALL';
      case LeadStatus.didNotConvert:
        return 'DID NOT CONVERT';
    }
  }
}