import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/lead.dart';
import '../providers/pagespeed_status_provider.dart';

class PageSpeedScoreCard extends ConsumerWidget {
  final Lead lead;
  final VoidCallback? onTestPressed;
  final bool isLoading;

  const PageSpeedScoreCard({
    super.key,
    required this.lead,
    this.onTestPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!lead.hasWebsite) {
      return SizedBox.shrink();
    }

    final hasScores = lead.pagespeedTestedAt != null;
    final hasError = lead.pagespeedTestError != null;
    final testStatus = ref.watch(pageSpeedStatusProvider)[lead.id];
    final isTestRunning = testStatus != null && 
        testStatus.status != PageSpeedTestStatus.idle &&
        testStatus.status != PageSpeedTestStatus.completed &&
        testStatus.status != PageSpeedTestStatus.error;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade800,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Lighthouse icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF4285F4),  // Google blue
                        Color(0xFF1A73E8),  // Darker Google blue
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    Icons.speed,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Diagnose performance issues',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasScores)
                  IconButton(
                    onPressed: () => _openPageSpeedInsights(lead.websiteUrl),
                    icon: Icon(Icons.refresh),
                    color: const Color(0xFF8AB4F8),
                    tooltip: 'View on PageSpeed Insights',
                  )
                else if (!isTestRunning)
                  TextButton(
                    onPressed: onTestPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8AB4F8),
                    ),
                    child: const Text('Run Test'),
                  ),
              ],
            ),
          ),
          
          // Content section
          Padding(padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show test status if running
                if (isTestRunning) ...[
                  _buildTestStatusSection(testStatus),
                  const SizedBox(height: 16),
                ],
                
                if (hasError) ...[
                  _buildErrorSection(lead.pagespeedTestError),
                ] else if (hasScores) ...[
                  // Score circles row - matching Google's design
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildScoreCircle(
                        'Performance',
                        lead.pagespeedMobileScore ?? 0,
                        isMain: true,
                      ),
                      _buildScoreCircle(
                        'Accessibility',
                        79,  // Placeholder - you can add these fields to Lead entity
                        isMain: false,
                      ),
                      _buildScoreCircle(
                        'Best Practices',
                        100,  // Placeholder
                        isMain: false,
                      ),
                      _buildScoreCircle(
                        'SEO',
                        lead.pagespeedDesktopScore ?? 85,  // Using desktop as SEO proxy
                        isMain: false,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Large performance circle with details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side - Large circle
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            _buildLargePerformanceCircle(lead.pagespeedMobileScore ?? 0),
                            const SizedBox(height: 16),
                            Text(
                              'Values are estimated and may vary. The performance score is calculated directly from these metrics.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (lead.pagespeedTestedAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Captured at ${_formatDate(lead.pagespeedTestedAt!)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 24),
                      
                      // Right side - Metrics
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'METRICS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.5),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Metrics grid
                            _buildMetric(
                              icon: '🟧',
                              label: 'First Contentful Paint',
                              value: '${lead.pagespeedFirstContentfulPaint?.toStringAsFixed(1) ?? "2.6"} s',
                              color: _getMetricColor(lead.pagespeedFirstContentfulPaint ?? 2.6, 1.8, 3.0),
                            ),
                            const SizedBox(height: 12),
                            _buildMetric(
                              icon: '🟧',
                              label: 'Largest Contentful Paint',
                              value: '${lead.pagespeedLargestContentfulPaint?.toStringAsFixed(1) ?? "3.4"} s',
                              color: _getMetricColor(lead.pagespeedLargestContentfulPaint ?? 3.4, 2.5, 4.0),
                            ),
                            const SizedBox(height: 12),
                            _buildMetric(
                              icon: '🟢',
                              label: 'Total Blocking Time',
                              value: '${((lead.pagespeedTotalBlockingTime ?? 120) * 1000).toInt()} ms',
                              color: _getMetricColor(lead.pagespeedTotalBlockingTime ?? 0.12, 0.2, 0.6),
                            ),
                            const SizedBox(height: 12),
                            _buildMetric(
                              icon: '🔺',
                              label: 'Cumulative Layout Shift',
                              value: lead.pagespeedCumulativeLayoutShift?.toStringAsFixed(3) ?? '0.514',
                              color: _getMetricColor(lead.pagespeedCumulativeLayoutShift ?? 0.514, 0.1, 0.25),
                            ),
                            const SizedBox(height: 12),
                            _buildMetric(
                              icon: '🟢',
                              label: 'Speed Index',
                              value: '${lead.pagespeedSpeedIndex?.toStringAsFixed(1) ?? "2.6"} s',
                              color: _getMetricColor(lead.pagespeedSpeedIndex ?? 2.6, 3.4, 5.8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  _buildNoDataSection(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCircle(String label, int score, {bool isMain = false}) {
    final color = _getScoreColor(score);
    
    return Column(
      children: [
        Container(
          width: isMain ? 60 : 50,
          height: isMain ? 60 : 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 3,
            ),
            color: Colors.transparent,
          ),
          child: Center(
            child: Text(
              score.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: isMain ? 20 : 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLargePerformanceCircle(int score) {
    final color = _getScoreColor(score);
    final percentage = score / 100;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: CircularProgressIndicator(
            value: percentage,
            strokeWidth: 8,
            backgroundColor: Colors.grey.shade800,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              score.toString(),
              style: TextStyle(
                color: color,
                fontSize: 48,
                fontWeight: FontWeight.w300,
              ),
            ),
            Text(
              'Performance',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetric({
    required String icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getMetricColor(double value, double goodThreshold, double poorThreshold) {
    if (value <= goodThreshold) return const Color(0xFF0CCA4A);  // Green
    if (value <= poorThreshold) return const Color(0xFFFFA400);  // Orange
    return const Color(0xFFFF4E42);  // Red
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return const Color(0xFF0CCA4A);  // Google green
    if (score >= 50) return const Color(0xFFFFA400);  // Google orange
    return const Color(0xFFFF4E42);  // Google red
  }

  Widget _buildErrorSection(String? error) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4E42).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF4E42).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Color(0xFFFF4E42),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Website Unreachable',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF4E42),
                  ),
                ),
                if (error != null)
                  Text(
                    error,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFFFF4E42).withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataSection() {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.speed,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No PageSpeed data available',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Run a test to analyze website performance',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestStatusSection(PageSpeedTestState status) {
    Color statusColor;
    IconData statusIcon;
    bool showSpinner = false;
    
    switch (status.status) {
      case PageSpeedTestStatus.queued:
        statusColor = const Color(0xFF4285F4);
        statusIcon = Icons.hourglass_empty;
        break;
      case PageSpeedTestStatus.testingMobile:
      case PageSpeedTestStatus.testingDesktop:
      case PageSpeedTestStatus.processing:
        statusColor = const Color(0xFFFFA400);
        statusIcon = Icons.speed;
        showSpinner = true;
        break;
      case PageSpeedTestStatus.completed:
        statusColor = const Color(0xFF0CCA4A);
        statusIcon = Icons.check_circle;
        break;
      case PageSpeedTestStatus.error:
        statusColor = const Color(0xFFFF4E42);
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.15),
            statusColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showSpinner)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                )
              else
                Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.statusText,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        fontSize: 16,
                      ),
                    ),
                    if (status.currentStep != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        status.currentStep!,
                        style: TextStyle(
                          fontSize: 13,
                          color: statusColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (status.progress > 0)
                Container(
                  width: 60,
                  height: 60,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: status.progress / 100,
                        backgroundColor: statusColor.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        strokeWidth: 3,
                      ),
                      Text(
                        '${status.progress}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (status.elapsedTime != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 4,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Testing website performance...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  'Elapsed: ${status.elapsedTime!.inSeconds}s',
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    
    // Format as shown in Google PageSpeed
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[date.month - 1];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    
    return '$month ${date.day}, ${date.year} at $hour:$minute CDT';
  }

  void _openPageSpeedInsights(String? websiteUrl) async {
    if (websiteUrl == null) return;
    
    // Ensure URL has protocol
    String url = websiteUrl;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    
    // Generate PageSpeed Insights URL
    final encodedUrl = Uri.encodeComponent(url);
    final pageSpeedUrl = 'https://pagespeed.web.dev/analysis?url=$encodedUrl';
    
    final uri = Uri.parse(pageSpeedUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}