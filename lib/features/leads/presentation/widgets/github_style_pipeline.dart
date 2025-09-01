import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/lead_detail_provider.dart';
import '../providers/job_provider.dart' show leadsRepositoryProvider;

class GitHubStylePipeline extends ConsumerStatefulWidget {
  final Lead lead;
  final VoidCallback? onStatusChanged;
  
  const GitHubStylePipeline({
    Key? key,
    required this.lead,
    this.onStatusChanged,
  }) : super(key: key);

  @override
  ConsumerState<GitHubStylePipeline> createState() => _GitHubStylePipelineState();
}

class _GitHubStylePipelineState extends ConsumerState<GitHubStylePipeline> {
  DateTime? _selectedCallbackDate;
  String? _callbackNote;
  
  // Layout configuration - GitHub Actions style
  static const double nodeSize = 32.0;
  static const double horizontalSpacing = 80.0;
  static const double containerHeight = 200.0;
  static const double lineHeight = 2.0;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: containerHeight,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_tree,
                  size: 16,
                  color: Colors.white.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Lead Pipeline',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(),
              ],
            ),
          ),
          
          // Pipeline visualization
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: _buildPipelineNodes(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusBadge() {
    final status = widget.lead.status;
    final isSuccess = status == LeadStatus.converted;
    final isFailed = status == LeadStatus.doNotCall || status == LeadStatus.didNotConvert;
    final isInProgress = !isSuccess && !isFailed;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSuccess 
            ? Colors.green.withOpacity(0.1)
            : isFailed 
                ? Colors.red.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess 
              ? Colors.green.withOpacity(0.3)
              : isFailed 
                  ? Colors.red.withOpacity(0.3)
                  : Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSuccess 
                ? Icons.check_circle
                : isFailed 
                    ? Icons.cancel
                    : Icons.pending,
            size: 12,
            color: isSuccess 
                ? Colors.green
                : isFailed 
                    ? Colors.red
                    : Colors.blue,
          ),
          const SizedBox(width: 4),
          Text(
            isSuccess 
                ? 'Success'
                : isFailed 
                    ? 'Failed'
                    : 'In Progress',
            style: TextStyle(
              color: isSuccess 
                  ? Colors.green
                  : isFailed 
                      ? Colors.red
                      : Colors.blue,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildPipelineNodes() {
    final nodes = <Widget>[];
    
    // Build main pipeline
    for (int i = 0; i < _mainPipeline.length; i++) {
      final node = _mainPipeline[i];
      final isActive = _isNodeActive(node);
      final isCurrent = node.status == widget.lead.status;
      final canInteract = _canInteractWithNode(node);
      
      // Add node
      nodes.add(_buildNode(
        node: node,
        isActive: isActive,
        isCurrent: isCurrent,
        canInteract: canInteract,
      ));
      
      // Add connector (except after last node)
      if (i < _mainPipeline.length - 1) {
        nodes.add(_buildConnector(
          isActive: isActive,
          isNext: !isActive && i == _getCurrentNodeIndex(),
        ));
      }
      
      // Add branch point after CALLED
      if (node.status == LeadStatus.called) {
        nodes.add(_buildBranchPoint());
      }
    }
    
    return nodes;
  }
  
  Widget _buildNode({
    required PipelineNode node,
    required bool isActive,
    required bool isCurrent,
    required bool canInteract,
  }) {
    return GestureDetector(
      onTap: canInteract ? () => _handleNodeAction(node) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: nodeSize,
            height: nodeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? _getNodeColor(node.status!)
                  : AppTheme.elevatedSurface,
              border: Border.all(
                color: isCurrent
                    ? Colors.white
                    : isActive
                        ? _getNodeColor(node.status!).withOpacity(0.6)
                        : Colors.white.withOpacity(0.2),
                width: isCurrent ? 2 : 1.5,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: _getNodeColor(node.status!).withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Icon(
                node.icon,
                size: 16,
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            node.label,
            style: TextStyle(
              color: isActive
                  ? Colors.white.withOpacity(0.9)
                  : Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (node.subtitle != null)
            Text(
              node.subtitle!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildConnector({
    required bool isActive,
    required bool isNext,
  }) {
    return Container(
      width: horizontalSpacing,
      height: lineHeight,
      margin: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [
                  AppTheme.primaryGold.withOpacity(0.6),
                  AppTheme.primaryGold.withOpacity(0.3),
                ]
              : isNext
                  ? [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ]
                  : [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.1),
                    ],
        ),
      ),
    );
  }
  
  Widget _buildBranchPoint() {
    final hasAlternativePath = 
        widget.lead.status == LeadStatus.callbackScheduled ||
        widget.lead.status == LeadStatus.doNotCall ||
        widget.lead.status == LeadStatus.didNotConvert;
    
    if (!hasAlternativePath) return const SizedBox(width: 0);
    
    return Container(
      margin: const EdgeInsets.only(left: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branch indicator
          Container(
            width: 2,
            height: 30,
            color: Colors.white.withOpacity(0.2),
          ),
          // Alternative path nodes
          Row(
            children: [
              if (widget.lead.status == LeadStatus.callbackScheduled)
                _buildNode(
                  node: PipelineNode(
                    status: LeadStatus.callbackScheduled,
                    label: 'Callback',
                    icon: Icons.event,
                    subtitle: _formatCallbackTime(),
                  ),
                  isActive: true,
                  isCurrent: true,
                  canInteract: false,
                ),
              if (widget.lead.status == LeadStatus.doNotCall)
                _buildNode(
                  node: PipelineNode(
                    status: LeadStatus.doNotCall,
                    label: 'Do Not Call',
                    icon: Icons.phone_disabled,
                  ),
                  isActive: true,
                  isCurrent: true,
                  canInteract: false,
                ),
              if (widget.lead.status == LeadStatus.didNotConvert)
                _buildNode(
                  node: PipelineNode(
                    status: LeadStatus.didNotConvert,
                    label: 'No Convert',
                    icon: Icons.trending_down,
                  ),
                  isActive: true,
                  isCurrent: true,
                  canInteract: false,
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  String? _formatCallbackTime() {
    if (widget.lead.followUpDate == null) return null;
    final now = DateTime.now();
    final callback = widget.lead.followUpDate!;
    final diff = callback.difference(now);
    
    if (diff.inDays > 0) {
      return 'In ${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return 'In ${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return 'In ${diff.inMinutes}m';
    } else {
      return 'Overdue';
    }
  }
  
  int _getCurrentNodeIndex() {
    return _mainPipeline.indexWhere((node) => node.status == widget.lead.status);
  }
  
  bool _isNodeActive(PipelineNode node) {
    final currentIndex = _getCurrentNodeIndex();
    final nodeIndex = _mainPipeline.indexOf(node);
    return nodeIndex <= currentIndex && currentIndex >= 0;
  }
  
  bool _canInteractWithNode(PipelineNode node) {
    // Cannot interact with terminal states
    if (widget.lead.status == LeadStatus.converted ||
        widget.lead.status == LeadStatus.doNotCall ||
        widget.lead.status == LeadStatus.didNotConvert) {
      return false;
    }
    
    final currentIndex = _getCurrentNodeIndex();
    final nodeIndex = _mainPipeline.indexOf(node);
    
    // Can move forward one step or backward (but not to NEW)
    return (nodeIndex == currentIndex + 1) || 
           (nodeIndex < currentIndex && nodeIndex > 0);
  }
  
  Future<void> _handleNodeAction(PipelineNode node) async {
    HapticFeedback.lightImpact();
    
    final currentIndex = _getCurrentNodeIndex();
    final nodeIndex = _mainPipeline.indexOf(node);
    final isUndo = nodeIndex < currentIndex;
    
    // Special handling for specific transitions
    if (node.status == LeadStatus.callbackScheduled) {
      await _showCallbackScheduler();
      return;
    }
    
    if (node.status == LeadStatus.didNotConvert) {
      await _showDidNotConvertDialog();
      return;
    }
    
    if (node.status == LeadStatus.doNotCall) {
      await _showDoNotCallDialog();
      return;
    }
    
    // Simple confirmation for other transitions
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.elevatedSurface,
        title: Text(
          isUndo ? 'Revert Status' : 'Update Status',
          style: const TextStyle(fontSize: 16),
        ),
        content: Text(
          isUndo 
              ? 'Revert lead status to ${node.label}?'
              : 'Update lead status to ${node.label}?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isUndo ? AppTheme.warningOrange : AppTheme.primaryBlue,
            ),
            child: Text(isUndo ? 'Revert' : 'Update'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _updateStatus(node.status!);
    }
  }
  
  Future<void> _showCallbackScheduler() async {
    // Implementation similar to skill tree version but with simpler UI
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final noteController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.elevatedSurface,
          title: const Text('Schedule Callback', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, size: 20),
                title: Text(
                  selectedDate == null
                      ? 'Select Date'
                      : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                  style: const TextStyle(fontSize: 14),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => selectedDate = date);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time, size: 20),
                title: Text(
                  selectedTime == null
                      ? 'Select Time'
                      : selectedTime!.format(context),
                  style: const TextStyle(fontSize: 14),
                ),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: 10, minute: 0),
                  );
                  if (time != null) {
                    setState(() => selectedTime = time);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Optional callback notes...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedDate != null && selectedTime != null
                  ? () {
                      _selectedCallbackDate = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      _callbackNote = noteController.text;
                      Navigator.pop(context, true);
                    }
                  : null,
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
    
    if (result == true && _selectedCallbackDate != null) {
      await _updateStatus(
        LeadStatus.callbackScheduled,
        metadata: {
          'callback_date': _selectedCallbackDate!.toIso8601String(),
          'callback_note': _callbackNote,
        },
      );
    }
  }
  
  Future<void> _showDidNotConvertDialog() async {
    // Simplified version
    String? reason;
    final reasons = [
      'Not Interested',
      'Too Expensive',
      'Using Competitor',
      'Bad Timing',
      'No Budget',
      'Other',
    ];
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.elevatedSurface,
          title: const Text('Mark as Did Not Convert', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please select a reason:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              ...reasons.map((r) => RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text(r, style: const TextStyle(fontSize: 13)),
                value: r,
                groupValue: reason,
                onChanged: (value) => setState(() => reason = value),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: reason != null
                  ? () => Navigator.pop(context, reason)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    
    if (result != null) {
      await _updateStatus(LeadStatus.didNotConvert, metadata: {'reason': result});
    }
  }
  
  Future<void> _showDoNotCallDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.elevatedSurface,
        title: const Text('Mark as Do Not Call', style: TextStyle(fontSize: 16)),
        content: const Text(
          'This will mark the lead as Do Not Call. Continue?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _updateStatus(LeadStatus.doNotCall);
    }
  }
  
  Future<void> _updateStatus(LeadStatus newStatus, {Map<String, dynamic>? metadata}) async {
    try {
      HapticFeedback.mediumImpact();
      
      final repository = ref.read(leadsRepositoryProvider);
      
      DateTime? followUpDate;
      if (newStatus == LeadStatus.callbackScheduled && metadata?['callback_date'] != null) {
        followUpDate = DateTime.parse(metadata!['callback_date']);
      }
      
      final updatedLead = widget.lead.copyWith(
        status: newStatus,
        followUpDate: followUpDate,
      );
      
      await repository.updateLead(updatedLead);
      
      await repository.addTimelineEntry(widget.lead.id, {
        'type': newStatus == LeadStatus.callbackScheduled ? 'FOLLOW_UP' : 'STATUS_CHANGE',
        'title': 'Status changed to ${_getStatusLabel(newStatus)}',
        'description': metadata?['callback_note'] ?? metadata?['reason'] ?? 
                      'Changed from ${_getStatusLabel(widget.lead.status)} to ${_getStatusLabel(newStatus)}',
        'follow_up_date': followUpDate?.toIso8601String(),
        'metadata': {
          ...?metadata,
          'previous_status': widget.lead.status.name,
          'new_status': newStatus.name,
        },
      });
      
      ref.invalidate(leadDetailProvider(widget.lead.id));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${_getStatusLabel(newStatus)}'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      widget.onStatusChanged?.call();
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
  
  Color _getNodeColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return Colors.grey;
      case LeadStatus.viewed:
        return Colors.blue;
      case LeadStatus.called:
        return Colors.orange;
      case LeadStatus.callbackScheduled:
        return Colors.purple;
      case LeadStatus.interested:
        return Colors.lightBlue;
      case LeadStatus.converted:
        return Colors.green;
      case LeadStatus.doNotCall:
        return Colors.red;
      case LeadStatus.didNotConvert:
        return Colors.deepOrange;
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
  
  // Pipeline definition
  final List<PipelineNode> _mainPipeline = [
    PipelineNode(
      status: LeadStatus.new_,
      label: 'New',
      icon: Icons.fiber_new,
    ),
    PipelineNode(
      status: LeadStatus.viewed,
      label: 'Viewed',
      icon: Icons.visibility,
    ),
    PipelineNode(
      status: LeadStatus.called,
      label: 'Called',
      icon: Icons.phone,
    ),
    PipelineNode(
      status: LeadStatus.interested,
      label: 'Interested',
      icon: Icons.star,
    ),
    PipelineNode(
      status: LeadStatus.converted,
      label: 'Converted',
      icon: Icons.check_circle,
    ),
  ];
}

class PipelineNode {
  final LeadStatus? status;
  final String label;
  final IconData icon;
  final String? subtitle;
  
  const PipelineNode({
    this.status,
    required this.label,
    required this.icon,
    this.subtitle,
  });
}