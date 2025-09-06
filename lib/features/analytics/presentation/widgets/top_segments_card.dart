import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analytics_providers.dart';

class TopSegmentsCard extends ConsumerWidget {
  const TopSegmentsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segmentsAsync = ref.watch(topSegmentsProvider);

    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Top Converting Segments',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Divider(color: Colors.white.withValues(alpha: 0.2)),
            segmentsAsync.when(
              data: (segments) => Column(
                children: [
                  if (segments.topIndustries.isNotEmpty) ...[
                    _SegmentSection(
                      title: 'Top Industries',
                      icon: Icons.business,
                      segments: segments.topIndustries,
                      nameKey: 'industry',
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (segments.topLocations.isNotEmpty) ...[
                    _SegmentSection(
                      title: 'Top Locations',
                      icon: Icons.location_on,
                      segments: segments.topLocations,
                      nameKey: 'location',
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (segments.ratingPerformance.isNotEmpty) ...[
                    _SegmentSection(
                      title: 'Rating Performance',
                      icon: Icons.star,
                      segments: segments.ratingPerformance,
                      nameKey: 'ratingBand',
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (segments.reviewPerformance.isNotEmpty) ...[
                    _SegmentSection(
                      title: 'Review Count Performance',
                      icon: Icons.reviews,
                      segments: segments.reviewPerformance,
                      nameKey: 'reviewBand',
                    ),
                  ],
                ],
              ),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(child: Padding(padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bar_chart_outlined,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No segment data yet',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Segments will appear with 3+ leads per category',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
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

class _SegmentSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<dynamic> segments;
  final String nameKey;

  const _SegmentSection({
    required this.title,
    required this.icon,
    required this.segments,
    required this.nameKey,
  });

  String _getName(dynamic segment) {
    switch (nameKey) {
      case 'industry':
        return segment.industry ?? 'Unknown';
      case 'location':
        return segment.location ?? 'Unknown';
      case 'ratingBand':
        return segment.ratingBand ?? 'Unknown';
      case 'reviewBand':
        return segment.reviewBand ?? 'Unknown';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...segments.take(5).map((segment) {
          final name = _getName(segment);
          final successScore = segment.successScore;
          final conversionRate = segment.conversionRate;
          final totalLeads = segment.totalLeads;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _StatChip(
                            label: 'Leads',
                            value: totalLeads.toString(),
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: 'Conv',
                            value: '$conversionRate%',
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getScoreColor(successScore).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getScoreColor(successScore).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${successScore.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(successScore),
                        ),
                      ),
                      Text(
                        'Score',
                        style: TextStyle(
                          fontSize: 10,
                          color: _getScoreColor(successScore),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 20) return Colors.green;
    if (score >= 10) return Colors.orange;
    return Colors.blue;
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}