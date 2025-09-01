import 'package:flutter/material.dart';
import '../../domain/entities/lead.dart';

class PageSpeedResultsWidget extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTestPressed;
  final bool isLoading;

  const PageSpeedResultsWidget({
    Key? key,
    required this.lead,
    required this.onTestPressed,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (lead.websiteUrl == null || lead.websiteUrl!.isEmpty) {
      return _buildNoWebsiteCard(context);
    }

    if (lead.pagespeedTestError != null) {
      return _buildErrorCard(context);
    }

    if (lead.pagespeedMobileScore == null && lead.pagespeedDesktopScore == null) {
      return _buildNotTestedCard(context);
    }

    return _buildResultsCard(context);
  }

  Widget _buildNoWebsiteCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: Colors.grey),
                const SizedBox(width: 8),
                Text('PageSpeed Insights',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text('No website available for testing',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final isUnreachable = lead.pagespeedTestError!.toLowerCase().contains('unreachable') ||
        lead.pagespeedTestError!.toLowerCase().contains('timeout');
    
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Text('Website Issue Detected',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (isUnreachable) ...[
              Chip(
                label: Text('UNREACHABLE WEBSITE'),
                backgroundColor: Colors.red.shade100,
                avatar: Icon(Icons.wifi_off, size: 16),
              ),
              const SizedBox(height: 8),
              Text('Website is broken or extremely slow',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 4),
            Text(lead.pagespeedTestError!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isLoading ? null : onTestPressed,
              icon: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.refresh),
              label: Text(isLoading ? 'Testing...' : 'Retry Test'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotTestedCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: Colors.blue),
                const SizedBox(width: 8),
                Text('PageSpeed Insights',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text('Website performance not tested yet'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isLoading ? null : onTestPressed,
              icon: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.play_arrow),
              label: Text(isLoading ? 'Testing...' : 'Run PageSpeed Test'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: Colors.green),
                const SizedBox(width: 8),
                Text('PageSpeed Results',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (lead.pagespeedTestedAt != null)
                  Text(
                    _formatTestDate(lead.pagespeedTestedAt!),
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildScoreCard('Mobile', lead.pagespeedMobileScore)),
                const SizedBox(width: 16),
                Expanded(child: _buildScoreCard('Desktop', lead.pagespeedDesktopScore)),
              ],
            ),
            if (lead.pagespeedMobileScore != null) ...[
              const SizedBox(height: 16),
              _buildMetrics(),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: isLoading ? null : onTestPressed,
              icon: Icon(Icons.refresh, size: 16),
              label: Text(isLoading ? 'Testing...' : 'Retest'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(String label, int? score) {
    final color = _getScoreColor(score);
    final category = _getScoreCategory(score);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            score?.toString() ?? 'N/A',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(category, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Performance Metrics', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (lead.pagespeedFirstContentfulPaint != null)
          _buildMetricRow('First Contentful Paint', 
              '${lead.pagespeedFirstContentfulPaint!.toStringAsFixed(1)}s'),
        if (lead.pagespeedLargestContentfulPaint != null)
          _buildMetricRow('Largest Contentful Paint', 
              '${lead.pagespeedLargestContentfulPaint!.toStringAsFixed(1)}s'),
        if (lead.pagespeedSpeedIndex != null)
          _buildMetricRow('Speed Index', 
              '${lead.pagespeedSpeedIndex!.toStringAsFixed(1)}s'),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _getScoreColor(int? score) {
    if (score == null) return Colors.grey;
    if (score >= 90) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  String _getScoreCategory(int? score) {
    if (score == null) return 'Not tested';
    if (score >= 90) return 'Good';
    if (score >= 50) return 'Needs work';
    return 'Poor';
  }

  String _formatTestDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}