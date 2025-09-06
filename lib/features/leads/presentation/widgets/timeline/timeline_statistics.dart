import 'package:flutter/material.dart';
import '../../../domain/entities/lead.dart';
import '../../../domain/entities/lead_timeline_entry.dart';
import 'timeline_color_scheme.dart';
import 'timeline_icon_mapper.dart';

class TimelineStatistics extends StatelessWidget {
  final Lead lead;
  final Map<TimelineEntryType, int> statistics;

  const TimelineStatistics({
    super.key,
    required this.lead,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    final totalEntries = statistics.values.fold(0, (sum, count) => sum + count);
    final topTypes = _getTopTypes();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Timeline Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalEntries entries',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...topTypes.map((entry) => _buildStatRow(entry.key, entry.value)),
          if (statistics.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(16),
                child: Text(
                  'No timeline entries yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<MapEntry<TimelineEntryType, int>> _getTopTypes() {
    final sorted = statistics.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  Widget _buildStatRow(TimelineEntryType type, int count) {
    final total = statistics.values.fold(0, (sum, c) => sum + c);
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    final color = TimelineColorScheme.getEntryColor(type);
    final icon = TimelineIconMapper.getEntryIcon(type);
    final label = TimelineIconMapper.getEntryLabel(type);

    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: count / (total > 0 ? total : 1),
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}