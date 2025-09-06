import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/lead_detail_provider.dart';
import '../providers/job_provider.dart' show leadsRepositoryProvider;

class LeadSkillTreePipeline extends ConsumerStatefulWidget {
  final Lead lead;
  final VoidCallback? onStatusChanged;
  
  const LeadSkillTreePipeline({
    super.key,
    required this.lead,
    this.onStatusChanged,
  });

  @override
  ConsumerState<LeadSkillTreePipeline> createState() => _LeadSkillTreePipelineState();
}

class _LeadSkillTreePipelineState extends ConsumerState<LeadSkillTreePipeline>
    with TickerProviderStateMixin {
  late AnimationController _flowController;
  late Animation<double> _flowAnimation;
  
  DateTime? _selectedCallbackDate;
  String? _callbackNote;
  
  // Layout configuration
  static const double nodeSize = 56.0;
    // static const double nodeSpacing = 100.0;
    // static const double verticalSpacing = 80.0;
  static const double containerHeight = 500.0;
    // static const double headerHeight = 80.0;
    // static const double contentStartY = 120.0;
  
  @override
  void initState() {
    super.initState();
    
    _flowController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _flowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_flowController);
  }
  
  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }
  
  Future<void> _handleNodeAction(SkillNode node) async {
    if (!_canProgressToNode(node)) return;
    
    HapticFeedback.lightImpact();
    
    // Special handling for callback scheduling
    if (node.status == LeadStatus.callbackScheduled) {
      await _showCallbackScheduler();
    } else if (node.requiresReason) {
      await _showReasonDialog(node);
    } else {
      await _showProgressConfirmation(node);
    }
  }
  
  bool _canProgressToNode(SkillNode node) {
    // Check if this node is accessible from current status
    final currentNode = _getNodeForStatus(widget.lead.status);
    if (currentNode == null) return false;
    
    // Allow going forward via connections
    if (currentNode.connections.contains(node.id)) {
      return true;
    }
    
    // Allow going backward (undo) to previous states
    // but not to terminal states or from terminal states
    if (widget.lead.status == LeadStatus.converted ||
        widget.lead.status == LeadStatus.doNotCall ||
        widget.lead.status == LeadStatus.didNotConvert) {
      return false;
    }
    
    // Allow going back to earlier states in the progression
    final currentIndex = _getStatusIndex(widget.lead.status);
    final targetIndex = _getStatusIndex(node.status!);
    
    // Can go back to previous states (except can't go back to NEW)
    if (targetIndex < currentIndex && targetIndex > 0) {
      return true;
    }
    
    return false;
  }
  
  SkillNode? _getNodeForStatus(LeadStatus status) {
    return _allNodes.firstWhere(
      (node) => node.status == status,
      orElse: () => _allNodes.first,
    );
  }
  
  Future<void> _showCallbackScheduler() async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final noteController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.elevatedSurface,
          title: const Row(
            children: [
              Icon(Icons.event, color: AppTheme.primaryGold),
              const SizedBox(width: 12),
              Text(
                'Schedule Callback',
                style: TextStyle(color: AppTheme.primaryGold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date picker
                ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text(
                    selectedDate == null
                        ? 'Select Date'
                        : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Icon(Icons.refresh),
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
                
                // Time picker
                ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text(
                    selectedTime == null
                        ? 'Select Time'
                        : selectedTime!.format(context),
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Icon(Icons.refresh),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 10, minute: 0),
                    );
                    if (time != null) {
                      setState(() => selectedTime = time);
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Notes field
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'Callback Notes',
                    hintText: 'What to discuss, preparation needed...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.refresh),
                  ),
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                ),
                
                const SizedBox(height: 16),
                
                // Info box
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You\'ll receive a notification when it\'s time to call back',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
              ),
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
  
  Future<void> _showReasonDialog(SkillNode node) async {
    // Implementation for did not convert reason dialog
    // Similar to the one in lead_status_actions.dart
  }
  
  Future<void> _showProgressConfirmation(SkillNode node) async {
    final currentIndex = _getStatusIndex(widget.lead.status);
    final targetIndex = _getStatusIndex(node.status!);
    final isUndo = targetIndex < currentIndex;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.elevatedSurface,
        title: Row(
          children: [
            Icon(
              isUndo ? Icons.undo : node.icon, 
              color: isUndo ? AppTheme.warningOrange : node.color
            ),
            const SizedBox(width: 12),
            Text(
              isUndo ? 'Revert to ${node.label}' : 'Progress to ${node.label}',
              style: const TextStyle(color: AppTheme.primaryGold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              node.description,
              style: const TextStyle(color: Colors.white),
            ),
            if (node.points > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      node.color.withValues(alpha: 0.2),
                      node.color.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: node.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, color: node.color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '+${node.points} XP',
                      style: TextStyle(
                        color: node.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: node.color),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _updateStatus(node.status!);
    }
  }
  
  Future<void> _updateStatus(LeadStatus newStatus, {Map<String, dynamic>? metadata}) async {
    try {
      HapticFeedback.mediumImpact();
      
      final repository = ref.read(leadsRepositoryProvider);
      
      // Update follow-up date if scheduling callback
      DateTime? followUpDate;
      if (newStatus == LeadStatus.callbackScheduled && metadata?['callback_date'] != null) {
        followUpDate = DateTime.parse(metadata!['callback_date']);
      }
      
      final updatedLead = widget.lead.copyWith(
        status: newStatus,
        followUpDate: followUpDate,
      );
      
      await repository.updateLead(updatedLead);
      
      // Add timeline entry
      await repository.addTimelineEntry(widget.lead.id, {
        'type': newStatus == LeadStatus.callbackScheduled ? 'FOLLOW_UP' : 'STATUS_CHANGE',
        'title': 'Status changed to ${_getStatusLabel(newStatus)}',
        'description': metadata?['callback_note'] ?? '',
        'follow_up_date': followUpDate?.toIso8601String(),
        'metadata': metadata,
      });
      
      ref.invalidate(leadDetailProvider(widget.lead.id));
      
      if (mounted) {
        if (newStatus == LeadStatus.converted) {
          HapticFeedback.heavyImpact();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus == LeadStatus.converted ? Icons.celebration : Icons.check_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text('Status updated to ${_getStatusLabel(newStatus)}'),
              ],
            ),
            backgroundColor: _getColorForStatus(newStatus),
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
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: containerHeight,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        children: [
          // Background with gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryBlue.withValues(alpha: 0.05),
                  AppTheme.primaryGold.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryGold.withValues(alpha: 0.1),
              ),
            ),
          ),
          
          // Skill tree visualization
          Padding(padding: EdgeInsets.all(20),
            child: CustomPaint(
              painter: SkillTreePainter(
                nodes: _allNodes,
                currentStatus: widget.lead.status,
                flowAnimation: _flowAnimation,
                theme: AppTheme.primaryGold,
              ),
              child: _buildInteractiveNodes(),
            ),
          ),
          
          // Header with XP
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildHeader(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    final xp = _calculateXP();
    final level = _calculateLevel(xp);
    final nextLevelXP = (level + 1) * 100;
    final progress = (xp % 100) / 100;
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGold.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Level badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryGold,
                  AppTheme.primaryGold.withValues(alpha: 0.7),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGold.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LVL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // XP Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sales Journey',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$xp / $nextLevelXP XP',
                      style: const TextStyle(
                        color: AppTheme.primaryGold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primaryGold),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInteractiveNodes() {
    return Stack(
      children: _allNodes.map((node) {
        final isActive = _isNodeActive(node);
        final isCurrent = node.status == widget.lead.status;
        final canProgress = _canProgressToNode(node);
        final currentIndex = _getStatusIndex(widget.lead.status);
        final targetIndex = _getStatusIndex(node.status!);
        final isUndoable = canProgress && targetIndex < currentIndex;
        
        return Positioned(
          left: node.position.dx - (nodeSize / 2),
          top: node.position.dy - (nodeSize / 2),
          child: GestureDetector(
            onTap: canProgress ? () => _handleNodeAction(node) : null,
            child: Container(
                  width: nodeSize,
                  height: nodeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isActive
                          ? [
                              node.color,
                              node.color.withValues(alpha: 0.6),
                            ]
                          : [
                              Colors.grey.withValues(alpha: 0.3),
                              Colors.grey.withValues(alpha: 0.1),
                            ],
                    ),
                    border: Border.all(
                      color: isCurrent
                          ? Colors.white
                          : isUndoable
                              ? AppTheme.warningOrange.withValues(alpha: 0.6)
                              : isActive
                                  ? node.color
                                  : Colors.grey.withValues(alpha: 0.3),
                      width: isCurrent ? 3 : isUndoable ? 2.5 : 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: node.color.withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        node.icon,
                        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
                        size: 20,
                      ),
                      if (node.points > 0)
                        Text(
                          '+${node.points}',
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
            ),
          ),
        );
      }).toList(),
    );
  }
  
  bool _isNodeActive(SkillNode node) {
    // Check if this node has been reached
    final statusIndex = _getStatusIndex(widget.lead.status);
    final nodeIndex = _getStatusIndex(node.status!);
    return nodeIndex <= statusIndex;
  }
  
  int _getStatusIndex(LeadStatus status) {
    final order = [
      LeadStatus.new_,
      LeadStatus.viewed,
      LeadStatus.called,
      LeadStatus.callbackScheduled,
      LeadStatus.interested,
      LeadStatus.converted,
      LeadStatus.doNotCall,
      LeadStatus.didNotConvert,
    ];
    return order.indexOf(status);
  }
  
  int _calculateXP() {
    // Calculate total XP based on progress
    int xp = 0;
    for (final node in _allNodes) {
      if (_isNodeActive(node)) {
        xp += node.points;
      }
    }
    return xp;
  }
  
  int _calculateLevel(int xp) {
    return (xp / 100).floor() + 1;
  }
  
  Color _getColorForStatus(LeadStatus status) {
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
  
  // Skill tree node definitions with better spacing
  final List<SkillNode> _allNodes = [
    SkillNode(
      id: 'new',
      status: LeadStatus.new_,
      label: 'NEW',
      icon: Icons.fiber_new,
      position: const Offset(60, 200),
      color: AppTheme.mediumGray,
      points: 0,
      description: 'Fresh lead discovered',
      connections: ['viewed'],
    ),
    SkillNode(
      id: 'viewed',
      status: LeadStatus.viewed,
      label: 'VIEWED',
      icon: Icons.visibility,
      position: const Offset(160, 200),
      color: Colors.blueGrey,
      points: 10,
      description: 'Lead reviewed and qualified',
      connections: ['called'],
    ),
    SkillNode(
      id: 'called',
      status: LeadStatus.called,
      label: 'CALLED',
      icon: Icons.phone_in_talk,
      position: const Offset(260, 200),
      color: AppTheme.warningOrange,
      points: 25,
      description: 'Initial contact made',
      connections: ['interested', 'callback', 'did_not_convert', 'do_not_call'],
    ),
    // Upper path - Success route
    SkillNode(
      id: 'interested',
      status: LeadStatus.interested,
      label: 'INTERESTED',
      icon: Icons.star,
      position: const Offset(380, 140),
      color: AppTheme.primaryBlue,
      points: 50,
      description: 'Lead shows strong interest',
      connections: ['converted'],
    ),
    SkillNode(
      id: 'converted',
      status: LeadStatus.converted,
      label: 'CONVERTED',
      icon: Icons.emoji_events,
      position: const Offset(500, 140),
      color: AppTheme.successGreen,
      points: 100,
      description: 'Deal closed! Victory!',
      connections: [],
      isGoal: true,
    ),
    // Middle path - Callback route
    SkillNode(
      id: 'callback',
      status: LeadStatus.callbackScheduled,
      label: 'CALLBACK',
      icon: Icons.event,
      position: const Offset(380, 200),
      color: Colors.purple,
      points: 15,
      description: 'Scheduled for follow-up',
      connections: ['interested', 'did_not_convert'],
    ),
    // Lower path - Failure routes
    SkillNode(
      id: 'did_not_convert',
      status: LeadStatus.didNotConvert,
      label: 'NO CONVERT',
      icon: Icons.trending_down,
      position: const Offset(380, 260),
      color: Colors.deepOrange,
      points: 5,
      description: 'Could not close the deal',
      connections: [],
      requiresReason: true,
    ),
    SkillNode(
      id: 'do_not_call',
      status: LeadStatus.doNotCall,
      label: 'DO NOT CALL',
      icon: Icons.phone_disabled,
      position: const Offset(380, 320),
      color: AppTheme.errorRed,
      points: 0,
      description: 'Lead requested no contact',
      connections: [],
    ),
  ];
}

class SkillNode {
  final String id;
  final LeadStatus? status;
  final String label;
  final IconData icon;
  final Offset position;
  final Color color;
  final int points;
  final String description;
  final List<String> connections;
  final bool isGoal;
  final bool requiresReason;
  
  SkillNode({
    required this.id,
    this.status,
    required this.label,
    required this.icon,
    required this.position,
    required this.color,
    required this.points,
    required this.description,
    required this.connections,
    this.isGoal = false,
    this.requiresReason = false,
  });
}

class SkillTreePainter extends CustomPainter {
  final List<SkillNode> nodes;
  final LeadStatus currentStatus;
  final Animation<double> flowAnimation;
  final Color theme;
  
  SkillTreePainter({
    required this.nodes,
    required this.currentStatus,
    required this.flowAnimation,
    required this.theme,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    // Draw connections with 90-degree angles
    for (final node in nodes) {
      for (final connectionId in node.connections) {
        final targetNode = nodes.firstWhere(
          (n) => n.id == connectionId,
          orElse: () => nodes.first,
        );
        
        // Check if this path is active
        final isActive = _isPathActive(node, targetNode);
        
        // Set the paint color based on active state
        paint.color = isActive
            ? theme.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.1);
        
        // Draw the connection with 90-degree angles
        _drawConnection(canvas, paint, node.position, targetNode.position, isActive);
      }
    }
  }
  
  void _drawConnection(Canvas canvas, Paint paint, Offset start, Offset end, bool isActive) {
    final path = Path();
    path.moveTo(start.dx, start.dy);
    
    // Determine the type of connection based on positions
    if ((start.dy - end.dy).abs() < 10) {
      // Horizontal connection
      path.lineTo(end.dx, end.dy);
    } else if ((start.dx - end.dx).abs() < 10) {
      // Vertical connection
      path.lineTo(end.dx, end.dy);
    } else {
      // Need 90-degree bend
      if (start.dx < end.dx) {
        // Moving right
        if (start.dy > end.dy) {
          // Moving up-right
          final midX = start.dx + (end.dx - start.dx) * 0.6;
          path.lineTo(midX, start.dy);
          path.lineTo(midX, end.dy);
          path.lineTo(end.dx, end.dy);
        } else {
          // Moving down-right
          final midX = start.dx + (end.dx - start.dx) * 0.6;
          path.lineTo(midX, start.dy);
          path.lineTo(midX, end.dy);
          path.lineTo(end.dx, end.dy);
        }
      } else {
        // Moving left (for callbacks)
        final midY = start.dy + (end.dy - start.dy) * 0.5;
        path.lineTo(start.dx, midY);
        path.lineTo(end.dx, midY);
        path.lineTo(end.dx, end.dy);
      }
    }
    
    if (isActive) {
      // Draw animated dashed line for active paths
      final dashPath = _createDashedPath(path, flowAnimation.value);
      canvas.drawPath(dashPath, paint);
      
      // Add glow effect
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = theme.withValues(alpha: 0.2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, glowPaint);
    } else {
      canvas.drawPath(path, paint);
    }
  }
  
  Path _createDashedPath(Path source, double phase) {
    final path = Path();
    final pathMetrics = source.computeMetrics();
    
    for (final metric in pathMetrics) {
      const dashLength = 10.0;
      const dashSpace = 5.0;
      final distance = metric.length;
      double start = phase * (dashLength + dashSpace);
      
      while (start < distance) {
        final end = math.min(start + dashLength, distance);
        path.addPath(
          metric.extractPath(start, end),
          Offset.zero,
        );
        start = end + dashSpace;
      }
    }
    
    return path;
  }
  
  bool _isPathActive(SkillNode from, SkillNode to) {
    // Check if this path has been traversed
    // final currentNode = nodes.firstWhere(
    //   (n) => n.status == currentStatus,
    //   orElse: () => nodes.first,
    // );
    
    // Simple check - path is active if we've reached the target
    return to.status != null && _getStatusIndex(to.status!) <= _getStatusIndex(currentStatus);
  }
  
  int _getStatusIndex(LeadStatus status) {
    final order = [
      LeadStatus.new_,
      LeadStatus.viewed,
      LeadStatus.called,
      LeadStatus.callbackScheduled,
      LeadStatus.interested,
      LeadStatus.converted,
      LeadStatus.doNotCall,
      LeadStatus.didNotConvert,
    ];
    return order.indexOf(status);
  }
  
  @override
  bool shouldRepaint(SkillTreePainter oldDelegate) {
    return oldDelegate.currentStatus != currentStatus ||
           oldDelegate.flowAnimation != flowAnimation;
  }
}