import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/job_provider.dart';
import '../../domain/entities/job.dart';

class ActiveJobsMonitor extends ConsumerWidget {
  const ActiveJobsMonitor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobState = ref.watch(jobProvider);
    
    if (!jobState.isRunning || jobState.currentJob == null) {
      return const SizedBox.shrink();
    }
    
    final job = jobState.currentJob!;
        
    return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1C1C1E),
                const Color(0xFF1C1C1E).withValues(alpha: 0.95),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.successGreen.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Active Job',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                // Job card
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: _JobCard(
                    job: job,
                    onComplete: () {
                      // Job completed, provider will handle removal
                    },
                  ),
                ),
              ],
            ),
          ),
        );
  }
}

class _JobCard extends StatefulWidget {
  final Job job;
  final VoidCallback onComplete;
  
  const _JobCard({required this.job, required this.onComplete});

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isCompleted = false;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }
  
  @override
  void didUpdateWidget(_JobCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if job just completed
    if (widget.job.status == JobStatus.done && !_isCompleted) {
      _isCompleted = true;
      // Wait 2 seconds then fade out
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _animationController.forward().then((_) {
            if (mounted) widget.onComplete();
          });
        }
      });
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final progress = job.total > 0 ? job.processed / job.total : 0.0;
    
    // Build display text from job data
    String displayText = '';
    if (job.industry != null && job.location != null) {
      displayText = '${job.industry} in ${job.location}';
    } else if (job.query != null) {
      displayText = job.query!;
    } else if (job.message != null) {
      displayText = job.message!;
      // Clean up common message patterns
      if (displayText.contains('Starting browser automation')) {
        displayText = 'Initializing search...';
      } else if (displayText.contains('Searching for businesses')) {
        displayText = 'Searching for businesses...';
      } else if (displayText.contains('Job created')) {
        displayText = 'Preparing search...';
      }
    } else {
      displayText = 'Processing...';
    }
    
    final leadsFound = job.processed;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: GestureDetector(
              onTap: () => context.go('/browser/monitor/${job.id}'),
              child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  job.status == JobStatus.done 
                      ? CupertinoIcons.checkmark_circle_fill
                      : job.status == JobStatus.error 
                          ? CupertinoIcons.exclamationmark_circle_fill
                          : CupertinoIcons.search,
                  size: 14,
                  color: job.status == JobStatus.done 
                      ? AppTheme.successGreen
                      : job.status == JobStatus.error 
                          ? AppTheme.errorRed
                          : Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    job.status == JobStatus.done 
                        ? 'Completed: $displayText'
                        : job.status == JobStatus.error 
                            ? 'Failed: $displayText'
                            : displayText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: job.status == JobStatus.done 
                          ? AppTheme.successGreen
                          : job.status == JobStatus.error 
                              ? AppTheme.errorRed
                              : Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$leadsFound leads found',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress < 0.3 ? AppTheme.warningOrange :
                      progress < 0.7 ? AppTheme.primaryBlue :
                      AppTheme.successGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
              ),
            ),
          ),
        );
      },
    );
  }
}