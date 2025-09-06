import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/active_jobs_provider.dart';
import '../../domain/entities/job.dart';

class ActiveJobsMonitor extends ConsumerStatefulWidget {
  const ActiveJobsMonitor({super.key});

  @override
  ConsumerState<ActiveJobsMonitor> createState() => _ActiveJobsMonitorState();
}

class _ActiveJobsMonitorState extends ConsumerState<ActiveJobsMonitor> 
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  
  @override
  void initState() {
    super.initState();
    _isExpanded = true; // Default to expanded
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeJobsState = ref.watch(activeJobsProvider);
    
    if (activeJobsState.jobs.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Get parent jobs (type == 'parent') and individual jobs
    // Updated to show all active jobs (up to 10 for parallel processing)
    final allParentJobs = activeJobsState.jobs.where((job) => job.type == 'parent').toList();
    final allIndividualJobs = activeJobsState.jobs.where((job) => job.type != 'parent').toList();
    
    // Show max 1 parent job and up to 10 individual jobs (matching parallel executor capacity)
    final parentJobs = allParentJobs.take(1).toList();
    final individualJobs = allIndividualJobs.take(10).toList();
    final totalJobs = activeJobsState.jobs.length;
        
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
                // Header - Now clickable for collapse/expand
                InkWell(
                  onTap: _toggleExpanded,
                  child: Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
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
                          totalJobs == 1 
                              ? 'Active Job'
                              : totalJobs > 10
                                  ? 'Active Jobs (${totalJobs.toString().replaceAllMapped(
                                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                      (Match m) => '${m[1]},'
                                    )})'
                                  : 'Active Jobs ($totalJobs)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const Spacer(),
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Collapsible content with max height constraint
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4, // Max 40% of screen height
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Parent jobs (full width)
                        ...parentJobs.map((job) => Padding(padding: const EdgeInsets.only(bottom: 8),
                          child: _JobCard(
                            job: job,
                            isParentJob: true,
                            onComplete: () {
                              ref.read(activeJobsProvider.notifier).removeJob(job.id);
                            },
                          ),
                        )),
                        // Individual jobs in responsive wrap
                        if (individualJobs.isNotEmpty)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate how many tiles fit horizontally
                              // Each tile needs ~200px minimum width + 8px gap
                              const tileMinWidth = 200.0;
                              const gap = 8.0;
                              final availableWidth = constraints.maxWidth;
                              final tilesPerRow = (availableWidth / (tileMinWidth + gap)).floor().clamp(1, 4);
                              final tileWidth = (availableWidth - (gap * (tilesPerRow - 1))) / tilesPerRow;
                              
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: individualJobs.map((job) => SizedBox(
                                  width: tileWidth,
                                  child: _JobCard(
                                    job: job,
                                    isParentJob: false,
                                    compact: tilesPerRow > 2, // Use compact mode for more tiles
                                    onComplete: () {
                                      ref.read(activeJobsProvider.notifier).removeJob(job.id);
                                    },
                                  ),
                                )).toList(),
                              );
                            },
                          ),
                        if (allIndividualJobs.length > 10)
                          Padding(padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '+ ${(allIndividualJobs.length - 10).toString().replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]},'
                              )} more jobs running...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                    ),
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
  final bool isParentJob;
  final bool compact;
  final VoidCallback onComplete;
  
  const _JobCard({
    required this.job, 
    this.isParentJob = false,
    this.compact = false,
    required this.onComplete,
  });

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
  
  String _getEstimatedTimeRemaining(DateTime startTime, int completed, int total) {
    if (completed == 0 || total == 0) return 'Calculating...';
    
    final elapsed = DateTime.now().difference(startTime);
    
    // If less than 5 seconds elapsed, show starting for better UX
    if (elapsed.inSeconds < 5) return 'Starting...';
    
    // If we have very little progress, estimate based on expected rate
    final rate = completed / elapsed.inSeconds; // items per second
    
    if (rate == 0 || rate < 0.001) {
      // Estimate based on typical rate (e.g., 1 search per 10 seconds for parallel jobs)
      final estimatedTotalSeconds = total * 10;
      final estimatedHours = (estimatedTotalSeconds / 3600).round();
      if (estimatedHours > 0) {
        return '~${estimatedHours}h estimated';
      }
      return 'Processing...';
    }
    
    final remaining = total - completed;
    final estimatedSeconds = (remaining / rate).round();
    
    // Handle negative or invalid values
    if (estimatedSeconds <= 0) return 'Almost done';
    
    if (estimatedSeconds < 60) {
      return '~${estimatedSeconds}s remaining';
    } else if (estimatedSeconds < 3600) {
      final minutes = (estimatedSeconds / 60).floor();
      final seconds = estimatedSeconds % 60;
      if (seconds > 0) {
        return '~${minutes}m ${seconds}s remaining';
      }
      return '~${minutes}m remaining';
    } else if (estimatedSeconds < 86400) {
      final hours = (estimatedSeconds / 3600).floor();
      final minutes = ((estimatedSeconds % 3600) / 60).floor();
      if (minutes > 0) {
        return '~${hours}h ${minutes}m remaining';
      }
      return '~${hours}h remaining';
    } else {
      final days = (estimatedSeconds / 86400).floor();
      final hours = ((estimatedSeconds % 86400) / 3600).floor();
      final minutes = ((estimatedSeconds % 3600) / 60).floor();
      if (hours > 0) {
        return '~${days}d ${hours}h ${minutes}m remaining';
      } else if (minutes > 0) {
        return '~${days}d ${minutes}m remaining';
      }
      return '~${days}d remaining';
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    
    // Handle parent jobs differently
    if (widget.isParentJob) {
      final completed = job.completedCombinations ?? 0;
      final total = job.totalCombinations ?? 0;
      final progress = total > 0 ? completed / total : 0.0;
      
      return AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGold.withValues(alpha: 0.1),
                      AppTheme.primaryGold.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryGold.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.grid_view_rounded,
                          size: 20,
                          color: AppTheme.primaryGold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parallel Search',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              Text(
                                '$total total searches',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$completed/$total',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: MediaQuery.of(context).size.width * progress,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryGold,
                                  AppTheme.primaryGold.withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}% complete',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          job.timestamp != null && completed > 0 
                              ? _getEstimatedTimeRemaining(job.timestamp!, completed, total)
                              : completed == 0 
                                  ? 'Starting...'
                                  : 'Calculating...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    if (job.message != null)
                      Padding(padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          job.message!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
    
    // Individual job display
    // Use leadsFound if available, otherwise fall back to processed
    final leadsFound = job.leadsFound ?? job.processed;
    final totalExpected = job.total > 0 ? job.total : 100; // Default to 100 if not set
    final progress = totalExpected > 0 ? (leadsFound / totalExpected).clamp(0.0, 1.0) : 0.0;
    
    // Build display text from job data
    String displayText = '';
    if (job.query != null && job.query!.isNotEmpty) {
      displayText = job.query!;
    } else if (job.industry != null && job.location != null) {
      displayText = '${job.industry} in ${job.location}';
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
        padding: EdgeInsets.all(widget.compact ? 10 : 12),
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
                      fontSize: widget.compact ? 12 : 13,
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
                      leadsFound > 0 ? '$leadsFound leads' : 'Searching...',
                      style: TextStyle(
                        fontSize: widget.compact ? 10 : 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      job.status == JobStatus.running && progress == 0 
                          ? 'Active' 
                          : '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: widget.compact ? 10 : 11,
                        fontWeight: FontWeight.w600,
                        color: job.status == JobStatus.running && progress == 0
                            ? AppTheme.warningOrange
                            : AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: job.status == JobStatus.running && progress == 0 
                        ? null  // Indeterminate progress for active jobs with no progress
                        : progress,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      job.status == JobStatus.running && progress == 0 
                          ? AppTheme.warningOrange :
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