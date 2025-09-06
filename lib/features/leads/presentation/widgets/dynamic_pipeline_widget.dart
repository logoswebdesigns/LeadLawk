import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_timeline_entry.dart';

/// Dynamic pipeline widget that shows different paths based on lead journey
/// Inspired by Pipedrive, HubSpot, and Salesforce pipeline visualization
class DynamicPipelineWidget extends ConsumerStatefulWidget {
  final Lead lead;
  final List<LeadTimelineEntry> timeline;
  final VoidCallback? onStatusChanged;
  
  const DynamicPipelineWidget({
    super.key,
    required this.lead,
    required this.timeline,
    this.onStatusChanged,
  });

  @override
  ConsumerState<DynamicPipelineWidget> createState() => _DynamicPipelineWidgetState();
}

class _DynamicPipelineWidgetState extends ConsumerState<DynamicPipelineWidget> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final route = _determineRoute();
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceDark,
            AppTheme.surfaceDark.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildHeader(route),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: _buildPipelineVisualization(route),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader(PipelineRoute route) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.route,
            size: 18,
            color: route.color,
          ),
          const SizedBox(width: 8),
          Text(
            route.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          _buildProgressIndicator(route),
        ],
      ),
    );
  }
  
  Widget _buildProgressIndicator(PipelineRoute route) {
    final progress = _calculateProgress(route);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: route.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: route.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 4,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(route.color),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              color: route.color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPipelineVisualization(PipelineRoute route) {
    return SizedBox(
      height: 220,
      child: CustomPaint(
        painter: PipelinePainter(
          route: route,
          currentStatus: widget.lead.status,
          animation: _pulseAnimation,
        ),
        child: SizedBox(
          width: route.getTotalWidth(),
          child: Stack(
            children: [
              // Main path nodes
              ...route.mainPath.asMap().entries.map((entry) {
                final index = entry.key;
                final node = entry.value;
                return _buildNode(
                  node: node,
                  position: route.getNodePosition(index, true),
                  isActive: _isNodeActive(node, route),
                  isCurrent: node.status == widget.lead.status,
                  canInteract: _canInteractWithNode(node),
                  route: route,
                );
              }),
              
              // Alternative path nodes (if any)
              if (route.alternativePaths.isNotEmpty)
                ...route.alternativePaths.entries.expand((pathEntry) {
                  return pathEntry.value.asMap().entries.map((entry) {
                    final index = entry.key;
                    final node = entry.value;
                    return _buildNode(
                      node: node,
                      position: route.getAlternativeNodePosition(
                        pathEntry.key,
                        index,
                      ),
                      isActive: _isNodeActive(node, route),
                      isCurrent: node.status == widget.lead.status,
                      canInteract: _canInteractWithNode(node),
                      route: route,
                    );
                  });
                }),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNode({
    required PipelineNode node,
    required Offset position,
    required bool isActive,
    required bool isCurrent,
    required bool canInteract,
    required PipelineRoute route,
  }) {
    return Positioned(
      left: position.dx - 20,
      top: position.dy - 20,
      child: GestureDetector(
        onTap: canInteract ? () => _handleNodeTap(node) : null,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final scale = isCurrent ? _pulseAnimation.value : 1.0;
            return Transform.scale(
              scale: scale,
              child: _buildNodeVisual(
                node: node,
                isActive: isActive,
                isCurrent: isCurrent,
                canInteract: canInteract,
                route: route,
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildNodeVisual({
    required PipelineNode node,
    required bool isActive,
    required bool isCurrent,
    required bool canInteract,
    required PipelineRoute route,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isActive
              ? RadialGradient(
                  colors: [
                    node.color.withValues(alpha: 0.9),
                    node.color.withValues(alpha: 0.6),
                  ],
                )
              : null,
            color: !isActive ? AppTheme.elevatedSurface : null,
            border: Border.all(
              color: isCurrent
                ? Colors.white
                : isActive
                  ? node.color
                  : Colors.white.withValues(alpha: 0.2),
              width: isCurrent ? 3 : 2,
            ),
            boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: node.color.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : isActive
                ? [
                    BoxShadow(
                      color: node.color.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ]
                : [],
          ),
          child: Center(child: Icon(
              node.icon,
              size: 20,
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 100),
          child: Column(
            children: [
              Text(
                node.label,
                style: TextStyle(
                  color: isActive
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (node.description != null) ...[
                const SizedBox(height: 2),
                Text(
                  node.description!,
                  style: TextStyle(
                    color: isActive
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.3),
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
  
  PipelineRoute _determineRoute() {
    // Analyze timeline to determine which route the lead is on
    final hasBeenCalled = _hasStatus(LeadStatus.called);
    final isConverted = widget.lead.status == LeadStatus.converted;
    final isDoNotCall = widget.lead.status == LeadStatus.doNotCall;
    final isDidNotConvert = widget.lead.status == LeadStatus.didNotConvert;
    final hasCallback = widget.lead.status == LeadStatus.callbackScheduled;
    
    if (isConverted) {
      return PipelineRoutes.successRoute;
    } else if (isDoNotCall) {
      return PipelineRoutes.doNotCallRoute;
    } else if (isDidNotConvert) {
      return PipelineRoutes.didNotConvertRoute;
    } else if (hasCallback) {
      return PipelineRoutes.callbackRoute;
    } else if (hasBeenCalled) {
      return PipelineRoutes.inProgressRoute;
    } else {
      return PipelineRoutes.standardRoute;
    }
  }
  
  bool _hasStatus(LeadStatus status) {
    return widget.timeline.any((entry) => 
      entry.type == TimelineEntryType.statusChange &&
      entry.metadata?['new_status'] == status.name
    ) || widget.lead.status == status;
  }
  
  bool _isNodeActive(PipelineNode node, PipelineRoute route) {
    final currentIndex = route.getCurrentIndex(widget.lead.status);
    final nodeIndex = route.getNodeIndex(node);
    return nodeIndex <= currentIndex;
  }
  
  bool _canInteractWithNode(PipelineNode node) {
    // Terminal states cannot be changed
    if (widget.lead.status == LeadStatus.converted ||
        widget.lead.status == LeadStatus.doNotCall ||
        widget.lead.status == LeadStatus.didNotConvert) {
      return false;
    }
    
    // Can only move to adjacent nodes
    final currentRoute = _determineRoute();
    final currentIndex = currentRoute.getCurrentIndex(widget.lead.status);
    final nodeIndex = currentRoute.getNodeIndex(node);
    
    return (nodeIndex == currentIndex + 1) || 
           (nodeIndex == currentIndex - 1 && nodeIndex > 0);
  }
  
  double _calculateProgress(PipelineRoute route) {
    final currentIndex = route.getCurrentIndex(widget.lead.status);
    final totalNodes = route.getTotalNodes();
    if (totalNodes <= 1) return 1.0;
    return (currentIndex + 1) / totalNodes;
  }
  
  Future<void> _handleNodeTap(PipelineNode node) async {
    HapticFeedback.lightImpact();
    
    // Implementation similar to existing pipeline
    // ... (reuse existing dialog logic)
  }
}

/// Custom painter for drawing pipeline connections
class PipelinePainter extends CustomPainter {
  final PipelineRoute route;
  final LeadStatus currentStatus;
  final Animation<double> animation;
  
  PipelinePainter({
    required this.route,
    required this.currentStatus,
    required this.animation,
  }) : super(repaint: animation);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    // Draw main path connections
    for (int i = 0; i < route.mainPath.length - 1; i++) {
      final start = route.getNodePosition(i, true);
      final end = route.getNodePosition(i + 1, true);
      
      final isActive = route.getCurrentIndex(currentStatus) > i;
      paint.color = isActive 
        ? route.color.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.2);
      
      if (isActive) {
        // Animated gradient for active connections
        paint.shader = LinearGradient(
          colors: [
            route.color.withValues(alpha: 0.8),
            route.color.withValues(alpha: 0.4),
          ],
        ).createShader(Rect.fromPoints(start, end));
      }
      
      canvas.drawLine(start, end, paint);
    }
    
    // Draw alternative path connections
    route.alternativePaths.forEach((branchPoint, nodes) {
      final branchIndex = route.getBranchPointIndex(branchPoint);
      if (branchIndex >= 0) {
        final branchStart = route.getNodePosition(branchIndex, true);
        
        for (int i = 0; i < nodes.length; i++) {
          final nodePos = route.getAlternativeNodePosition(branchPoint, i);
          
          final isOnThisPath = nodes.any((n) => n.status == currentStatus);
          paint.shader = null;
          paint.color = isOnThisPath
            ? route.color.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.1);
          
          // Draw branch connection
          final path = Path()
            ..moveTo(branchStart.dx, branchStart.dy)
            ..quadraticBezierTo(
              branchStart.dx + 20,
              branchStart.dy + 20,
              nodePos.dx,
              nodePos.dy,
            );
          
          canvas.drawPath(path, paint);
        }
      }
    });
  }
  
  @override
  bool shouldRepaint(PipelinePainter oldDelegate) {
    return oldDelegate.currentStatus != currentStatus ||
           oldDelegate.route != route;
  }
}

/// Pipeline node representation
class PipelineNode {
  final LeadStatus status;
  final String label;
  final IconData icon;
  final Color color;
  final String? description;
  
  PipelineNode({
    required this.status,
    required this.label,
    required this.icon,
    required this.color,
    this.description,
  });
}

/// Pipeline route definition
class PipelineRoute {
  final String name;
  final Color color;
  final List<PipelineNode> mainPath;
  final Map<LeadStatus, List<PipelineNode>> alternativePaths;
  
  PipelineRoute({
    required this.name,
    required this.color,
    required this.mainPath,
    this.alternativePaths = const {},
  });
  
  int getCurrentIndex(LeadStatus status) {
    final mainIndex = mainPath.indexWhere((n) => n.status == status);
    if (mainIndex >= 0) return mainIndex;
    
    // Check alternative paths
    for (final nodes in alternativePaths.values) {
      if (nodes.any((n) => n.status == status)) {
        // Return the branch point index
        final branchStatus = alternativePaths.keys.firstWhere(
          (key) => alternativePaths[key]!.any((n) => n.status == status),
        );
        return mainPath.indexWhere((n) => n.status == branchStatus);
      }
    }
    
    return -1;
  }
  
  int getNodeIndex(PipelineNode node) {
    return mainPath.indexOf(node);
  }
  
  int getBranchPointIndex(LeadStatus status) {
    return mainPath.indexWhere((n) => n.status == status);
  }
  
  int getTotalNodes() {
    return mainPath.length;
  }
  
  double getTotalWidth() {
    return (mainPath.length * 120.0) + 100;
  }
  
  Offset getNodePosition(int index, bool isMainPath) {
    final x = 50.0 + (index * 120.0);
    final y = isMainPath ? 80.0 : 150.0;
    return Offset(x, y);
  }
  
  Offset getAlternativeNodePosition(LeadStatus branchPoint, int index) {
    final branchIndex = getBranchPointIndex(branchPoint);
    final x = 50.0 + (branchIndex * 120.0) + ((index + 1) * 80.0);
    const y = 150.0;
    return Offset(x, y);
  }
}

/// Predefined pipeline routes based on CRM best practices
class PipelineRoutes {
  static final standardRoute = PipelineRoute(
    name: 'Standard Pipeline',
    color: AppTheme.primaryBlue,
    mainPath: [
      PipelineNode(
        status: LeadStatus.new_, // This represents the CREATED state
        label: 'Created',
        icon: Icons.add_circle_outline,
        color: Colors.blueGrey,
        description: 'Discovered',
      ),
      PipelineNode(
        status: LeadStatus.viewed,
        label: 'Viewed',
        icon: Icons.visibility,
        color: Colors.blue,
        description: 'Reviewed',
      ),
      PipelineNode(
        status: LeadStatus.called,
        label: 'Called',
        icon: Icons.phone,
        color: Colors.orange,
        description: 'Contacted',
      ),
      PipelineNode(
        status: LeadStatus.interested,
        label: 'Interested',
        icon: Icons.star,
        color: Colors.amber,
        description: 'Interested',
      ),
      PipelineNode(
        status: LeadStatus.converted,
        label: 'Converted',
        icon: Icons.check_circle,
        color: Colors.green,
        description: 'Closed',
      ),
    ],
  );
  
  static final successRoute = PipelineRoute(
    name: 'Conversion Success',
    color: Colors.green,
    mainPath: standardRoute.mainPath,
  );
  
  static final inProgressRoute = PipelineRoute(
    name: 'In Progress',
    color: AppTheme.primaryGold,
    mainPath: standardRoute.mainPath.sublist(0, 4),
  );
  
  static final callbackRoute = PipelineRoute(
    name: 'Callback Scheduled',
    color: Colors.purple,
    mainPath: standardRoute.mainPath.sublist(0, 3),
    alternativePaths: {
      LeadStatus.called: [
        PipelineNode(
          status: LeadStatus.callbackScheduled,
          label: 'Callback',
          icon: Icons.event,
          color: Colors.purple,
          description: 'Scheduled',
        ),
      ],
    },
  );
  
  static final didNotConvertRoute = PipelineRoute(
    name: 'Did Not Convert',
    color: Colors.deepOrange,
    mainPath: standardRoute.mainPath.sublist(0, 3),
    alternativePaths: {
      LeadStatus.called: [
        PipelineNode(
          status: LeadStatus.didNotConvert,
          label: 'No Convert',
          icon: Icons.trending_down,
          color: Colors.deepOrange,
          description: 'Lost',
        ),
      ],
    },
  );
  
  static final doNotCallRoute = PipelineRoute(
    name: 'Do Not Call',
    color: Colors.red,
    mainPath: standardRoute.mainPath.sublist(0, 3),
    alternativePaths: {
      LeadStatus.called: [
        PipelineNode(
          status: LeadStatus.doNotCall,
          label: 'Do Not Call',
          icon: Icons.phone_disabled,
          color: Colors.red,
          description: 'DNC',
        ),
      ],
    },
  );
}