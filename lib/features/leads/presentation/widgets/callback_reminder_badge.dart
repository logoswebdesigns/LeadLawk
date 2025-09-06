import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';

class CallbackReminderBadge extends StatefulWidget {
  final Lead lead;
  
  const CallbackReminderBadge({
    super.key,
    required this.lead,
  });
  
  @override
  State<CallbackReminderBadge> createState() => _CallbackReminderBadgeState();
}

class _CallbackReminderBadgeState extends State<CallbackReminderBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  Timer? _timer;
  bool _isOverdue = false;
  String _timeRemaining = '';
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _updateTimer();
    _timer = Timer.periodic(Duration(minutes: 1), (_) => _updateTimer());
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
  
  void _updateTimer() {
    if (widget.lead.status != LeadStatus.callbackScheduled || 
        widget.lead.followUpDate == null) {
      return;
    }
    
    final now = DateTime.now();
    final callbackTime = widget.lead.followUpDate!;
    final difference = callbackTime.difference(now);
    
    setState(() {
      _isOverdue = difference.isNegative;
      
      if (_isOverdue) {
        _animationController.repeat(reverse: true);
        final overdueDuration = now.difference(callbackTime);
        if (overdueDuration.inDays > 0) {
          _timeRemaining = '${overdueDuration.inDays}d overdue';
        } else if (overdueDuration.inHours > 0) {
          _timeRemaining = '${overdueDuration.inHours}h overdue';
        } else {
          _timeRemaining = '${overdueDuration.inMinutes}m overdue';
        }
      } else {
        if (difference.inHours < 1) {
          // Less than an hour - urgent!
          _animationController.repeat(reverse: true);
          _timeRemaining = 'In ${difference.inMinutes}m';
        } else if (difference.inDays == 0) {
          // Today
          _timeRemaining = 'Today ${_formatTime(callbackTime)}';
        } else if (difference.inDays == 1) {
          // Tomorrow
          _timeRemaining = 'Tomorrow';
        } else if (difference.inDays < 7) {
          // This week
          _timeRemaining = 'In ${difference.inDays}d';
        } else {
          // More than a week
          _animationController.stop();
          _timeRemaining = '${callbackTime.day}/${callbackTime.month}';
        }
      }
    });
  }
  
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.lead.status != LeadStatus.callbackScheduled || 
        widget.lead.followUpDate == null) {
      return SizedBox.shrink();
    }
    
    final color = _isOverdue 
        ? AppTheme.errorRed 
        : (widget.lead.followUpDate!.difference(DateTime.now()).inHours < 24 
            ? AppTheme.warningOrange 
            : Colors.purple);
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Transform.scale(
        scale: _pulseAnimation.value,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color,
                color.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isOverdue ? Icons.notification_important : Icons.event,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                _timeRemaining,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}