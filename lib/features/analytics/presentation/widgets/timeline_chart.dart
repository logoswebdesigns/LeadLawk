import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analytics_providers.dart';

class TimelineChart extends ConsumerWidget {
  const TimelineChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(conversionTimelineProvider);

    return Card(
      color: Colors.white.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Conversion Timeline (30 Days)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Divider(color: Colors.white.withOpacity(0.2)),
            timelineAsync.when(
              data: (timeline) {
                if (timeline.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No timeline data available',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    ),
                  );
                }
                
                // Calculate max values for scaling
                final maxConversions = timeline
                    .map((e) => e.conversions)
                    .reduce((a, b) => a > b ? a : b);
                final maxLeads = timeline
                    .map((e) => e.newLeads)
                    .reduce((a, b) => a > b ? a : b);
                final maxValue = maxConversions > maxLeads ? maxConversions : maxLeads;
                
                // Show last 7 days for better visibility
                final recentTimeline = timeline.length > 7 
                    ? timeline.sublist(timeline.length - 7)
                    : timeline;
                
                return Column(
                  children: [
                    // Chart
                    SizedBox(
                      height: 200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: recentTimeline.map((point) {
                          final date = DateTime.parse(point.date);
                          final dayLabel = '${date.month}/${date.day}';
                          
                          return Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Bar chart
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // New leads bar
                                      _ChartBar(
                                        value: point.newLeads,
                                        maxValue: maxValue > 0 ? maxValue : 1,
                                        color: Colors.blue,
                                        width: 15,
                                      ),
                                      const SizedBox(width: 2),
                                      // Conversions bar
                                      _ChartBar(
                                        value: point.conversions,
                                        maxValue: maxValue > 0 ? maxValue : 1,
                                        color: Colors.green,
                                        width: 15,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Date label
                                Text(
                                  dayLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LegendItem(
                          color: Colors.blue,
                          label: 'New Leads',
                        ),
                        const SizedBox(width: 24),
                        _LegendItem(
                          color: Colors.green,
                          label: 'Conversions',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Summary stats
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _SummaryItem(
                            label: 'Total New Leads',
                            value: timeline
                                .map((e) => e.newLeads)
                                .reduce((a, b) => a + b)
                                .toString(),
                            color: Colors.blue,
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.grey[400],
                          ),
                          _SummaryItem(
                            label: 'Total Conversions',
                            value: timeline
                                .map((e) => e.conversions)
                                .reduce((a, b) => a + b)
                                .toString(),
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.timeline_outlined,
                        color: Colors.white.withOpacity(0.5),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No timeline data yet',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Timeline will appear as you work with leads',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
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

class _ChartBar extends StatelessWidget {
  final int value;
  final int maxValue;
  final Color color;
  final double width;

  const _ChartBar({
    required this.value,
    required this.maxValue,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final height = maxValue > 0 ? (value / maxValue) : 0.0;
    
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: width,
        height: height * 150, // Max height of 150
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
        child: value > 0
            ? Center(
                child: Text(
                  value.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}