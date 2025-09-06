import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/lead_detail_provider.dart';
import '../providers/job_provider.dart' show leadsRepositoryProvider;

class LeadPipelineProgress extends ConsumerStatefulWidget {
  final Lead lead;
  final VoidCallback? onStatusChanged;
  
  const LeadPipelineProgress({
    super.key,
    required this.lead,
    this.onStatusChanged,
  });

  @override
  ConsumerState<LeadPipelineProgress> createState() => _LeadPipelineProgressState();
}

class _LeadPipelineProgressState extends ConsumerState<LeadPipelineProgress>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _celebrationController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _celebrationAnimation;
  late Animation<double> _pulseAnimation;
  
  // Pipeline stages
  final List<PipelineStage> _stages = [
    PipelineStage(
      status: LeadStatus.new_,
      label: 'NEW',
      icon: Icons.fiber_new,
      points: 0,
      description: 'Fresh lead discovered',
    ),
    PipelineStage(
      status: LeadStatus.viewed,
      label: 'VIEWED',
      icon: Icons.visibility,
      points: 10,
      description: 'Lead reviewed and qualified',
    ),
    PipelineStage(
      status: LeadStatus.called,
      label: 'CALLED',
      icon: Icons.phone_in_talk,
      points: 25,
      description: 'Initial contact made',
    ),
    PipelineStage(
      status: LeadStatus.interested,
      label: 'INTERESTED',
      icon: Icons.star,
      points: 50,
      description: 'Lead shows interest',
    ),
    PipelineStage(
      status: LeadStatus.converted,
      label: 'CONVERTED',
      icon: Icons.emoji_events,
      points: 100,
      description: 'Deal closed! 🎉',
      isGoal: true,
    ),
  ];

  int get _currentStageIndex {
    return _stages.indexWhere((stage) => stage.status == widget.lead.status);
  }

  double get _progressPercentage {
    if (_currentStageIndex < 0) return 0.0;
    if (widget.lead.status == LeadStatus.converted) return 1.0;
    if (widget.lead.status == LeadStatus.doNotCall || 
        widget.lead.status == LeadStatus.didNotConvert) {
      // Show progress up to current stage but grayed out
      return (_currentStageIndex + 0.5) / _stages.length;
    }
    return (_currentStageIndex + 1) / _stages.length;
  }

  @override
  void initState() {
    super.initState();
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: _progressPercentage,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    ));
    
    _celebrationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.elasticOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start initial animation
    _progressController.forward();
    
    // Check if we should celebrate
    if (widget.lead.status == LeadStatus.converted) {
      _triggerCelebration();
    }
  }

  @override
  void didUpdateWidget(LeadPipelineProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.lead.status != widget.lead.status) {
      _animateTransition(oldWidget.lead.status, widget.lead.status);
    }
  }

  void _animateTransition(LeadStatus from, LeadStatus to) {
    // Trigger haptic feedback
    HapticFeedback.mediumImpact();
    
    // Update progress animation
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: _progressPercentage,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    ));
    
    _progressController.forward(from: 0);
    
    // Special celebration for conversion
    if (to == LeadStatus.converted) {
      _triggerCelebration();
    }
    
    // Callback
    widget.onStatusChanged?.call();
  }

  void _triggerCelebration() {
    HapticFeedback.heavyImpact();
    _celebrationController.forward(from: 0);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _celebrationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleStageAction(PipelineStage stage) async {
    if (_canProgressToStage(stage)) {
      // Show confirmation with preview
      final confirmed = await _showStageProgressDialog(stage);
      if (confirmed == true) {
        await _updateStatus(stage.status);
      }
    }
  }

  bool _canProgressToStage(PipelineStage stage) {
    final currentIndex = _currentStageIndex;
    final targetIndex = _stages.indexOf(stage);
    
    // Can't go backwards past viewed
    if (targetIndex < 1 && currentIndex > targetIndex) return false;
    
    // Can't skip more than one stage forward
    if (targetIndex > currentIndex + 1) return false;
    
    // Can't progress from terminal states
    if (widget.lead.status == LeadStatus.converted ||
        widget.lead.status == LeadStatus.doNotCall ||
        widget.lead.status == LeadStatus.didNotConvert) {
      return false;
    }
    
    return true;
  }

  Future<bool?> _showStageProgressDialog(PipelineStage stage) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.elevatedSurface,
        title: Row(
          children: [
            Icon(stage.icon, color: _getStageColor(stage)),
            const SizedBox(width: 12),
            Text(
              'Progress to ${stage.label}',
              style: const TextStyle(color: AppTheme.primaryGold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stage.description,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStageColor(stage).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStageColor(stage).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: _getStageColor(stage),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${stage.points} points',
                    style: TextStyle(
                      color: _getStageColor(stage),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStageColor(stage),
            ),
            child: const Text('Progress'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(LeadStatus newStatus) async {
    try {
      final repository = ref.read(leadsRepositoryProvider);
      
      // Create timeline entry
      final timelineData = {
        'type': 'STATUS_CHANGE',
        'title': 'Progressed to ${_getStatusLabel(newStatus)}',
        'description': 'Pipeline progression',
        'metadata': {
          'points_earned': _stages.firstWhere((s) => s.status == newStatus).points,
        },
      };
      
      // Update the lead
      final updatedLead = widget.lead.copyWith(status: newStatus);
      
      await repository.updateLead(updatedLead);
      await repository.addTimelineEntry(widget.lead.id, timelineData);
      
      // Refresh the lead details
      ref.invalidate(leadDetailProvider(widget.lead.id));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.celebration, color: Colors.white),
                const SizedBox(width: 8),
                Text('Advanced to ${_getStatusLabel(newStatus)}!'),
              ],
            ),
            backgroundColor: _getStageColor(
              _stages.firstWhere((s) => s.status == newStatus),
            ),
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

  @override
  Widget build(BuildContext context) {
    // final isTerminal = widget.lead.status == LeadStatus.converted ||
                      widget.lead.status == LeadStatus.doNotCall ||
                      widget.lead.status == LeadStatus.didNotConvert;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with score
          _buildHeader(),
          const SizedBox(height: 24),
          
          // Pipeline visualization
          _buildPipeline(),
          const SizedBox(height: 32),
          
          // Stage cards
          _buildStageCards(),
          
          // Celebration overlay
          if (widget.lead.status == LeadStatus.converted)
            _buildCelebrationOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final currentStage = _stages.firstWhere(
      (s) => s.status == widget.lead.status,
      orElse: () => _stages.first,
    );
    
    final totalPoints = _stages
        .where((s) => _stages.indexOf(s) <= _currentStageIndex)
        .fold(0, (sum, stage) => sum + stage.points);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Pipeline',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            Text(
              currentStage.label,
              style: TextStyle(
                color: _getStageColor(currentStage),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: widget.lead.status == LeadStatus.interested ? _pulseAnimation.value : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGold,
                    AppTheme.primaryGold.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGold.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$totalPoints pts',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPipeline() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Background track
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            
            // Progress fill
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Container(
                  height: 8,
                  width: constraints.maxWidth * _progressAnimation.value,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.lead.status == LeadStatus.converted
                          ? [AppTheme.successGreen, Colors.greenAccent]
                          : widget.lead.status == LeadStatus.doNotCall ||
                            widget.lead.status == LeadStatus.didNotConvert
                              ? [Colors.grey, Colors.grey.shade600]
                              : [AppTheme.primaryBlue, AppTheme.primaryGold],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: widget.lead.status == LeadStatus.converted
                            ? AppTheme.successGreen.withValues(alpha: 0.5)
                            : AppTheme.primaryGold.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            // Stage markers
            ...List.generate(_stages.length, (index) {
              final stage = _stages[index];
              final position = (index / (_stages.length - 1)) * constraints.maxWidth;
              final isActive = index <= _currentStageIndex;
              final isCurrent = stage.status == widget.lead.status;
              
              return Positioned(
                left: position - 20,
                top: -16,
                child: GestureDetector(
                  onTap: () => _handleStageAction(stage),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? _getStageColor(stage)
                          : Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: isCurrent
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                        width: isCurrent ? 3 : 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: _getStageColor(stage).withValues(alpha: 0.5),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Icon(
                        stage.icon,
                        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
                        size: isCurrent ? 24 : 20,
                      ),
                    ),
                  ),
                ),
              );
            }),
            
            // Animated current position indicator
            if (_currentStageIndex >= 0)
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  final position = _progressAnimation.value * constraints.maxWidth;
                  return Positioned(
                    left: position - 4,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildStageCards() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _stages.length,
        itemBuilder: (context, index) {
          final stage = _stages[index];
          final isActive = index <= _currentStageIndex;
          final isCurrent = stage.status == widget.lead.status;
          final canProgress = _canProgressToStage(stage);
          
          return GestureDetector(
            onTap: canProgress ? () => _handleStageAction(stage) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isActive
                      ? [
                          _getStageColor(stage),
                          _getStageColor(stage).withValues(alpha: 0.7),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrent
                      ? Colors.white
                      : isActive
                          ? _getStageColor(stage).withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.1),
                  width: isCurrent ? 2 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: _getStageColor(stage).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        stage.icon,
                        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
                        size: 24,
                      ),
                      if (stage.isGoal)
                        const Icon(
                          Icons.star,
                          color: Colors.yellow,
                          size: 20,
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage.label,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${stage.points} pts',
                        style: TextStyle(
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.3),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  if (canProgress && !isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Tap to progress',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCelebrationOverlay() {
    return AnimatedBuilder(
      animation: _celebrationAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: ConfettiPainter(
                progress: _celebrationAnimation.value,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStageColor(PipelineStage stage) {
    switch (stage.status) {
      case LeadStatus.new_:
        return AppTheme.mediumGray;
      case LeadStatus.viewed:
        return Colors.blueGrey;
      case LeadStatus.called:
        return AppTheme.warningOrange;
      case LeadStatus.interested:
        return AppTheme.primaryBlue;
      case LeadStatus.converted:
        return AppTheme.successGreen;
      default:
        return AppTheme.mediumGray;
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

class PipelineStage {
  final LeadStatus status;
  final String label;
  final IconData icon;
  final int points;
  final String description;
  final bool isGoal;

  PipelineStage({
    required this.status,
    required this.label,
    required this.icon,
    required this.points,
    required this.description,
    this.isGoal = false,
  });
}

class ConfettiPainter extends CustomPainter {
  final double progress;
  final math.Random random = math.Random();

  ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final paint = Paint();
    final colors = [
      AppTheme.primaryGold,
      AppTheme.successGreen,
      Colors.yellow,
      Colors.orange,
      Colors.pink,
    ];

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      const startY = -50.0;
      final endY = size.height + 50;
      final y = startY + (endY - startY) * progress;
      
      final rotation = random.nextDouble() * math.pi * 2 * progress;
      
      paint.color = colors[i % colors.length].withValues(alpha: (1 - progress) * 0.8);
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 10, height: 6),
        paint,
      );
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}