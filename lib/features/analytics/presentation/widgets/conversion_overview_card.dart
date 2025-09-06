import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analytics_providers.dart';

class ConversionOverviewCard extends ConsumerWidget {
  const ConversionOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(conversionOverviewProvider);

    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      child: Padding(padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.refresh),
                const SizedBox(width: 8),
                Text(
                  'Conversion Overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Divider(color: Colors.white.withValues(alpha: 0.2)),
            overviewAsync.when(
              data: (overview) => Column(
                children: [
                  // Main metrics row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MetricTile(
                        label: 'Total Leads',
                        value: overview.totalLeads.toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                      _MetricTile(
                        label: 'Converted',
                        value: overview.converted.toString(),
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                      _MetricTile(
                        label: 'Interested',
                        value: overview.interested.toString(),
                        icon: Icons.star,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Conversion rates
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        _RateRow(
                          label: 'Conversion Rate',
                          value: '${overview.conversionRate}%',
                          color: Colors.green,
                        ),
                        const SizedBox(height: 8),
                        _RateRow(
                          label: 'Interest Rate',
                          value: '${overview.interestRate}%',
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        _RateRow(
                          label: 'Contact Rate',
                          value: '${overview.contactRate}%',
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Status breakdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatusChip(
                        label: 'New',
                        count: overview.newLeads,
                        color: Colors.blue,
                      ),
                      _StatusChip(
                        label: 'Called',
                        count: overview.called,
                        color: Colors.purple,
                      ),
                      _StatusChip(
                        label: 'DNC',
                        count: overview.dnc,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(child: Padding(padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No data available yet',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toggle "Demo" above to see sample data',
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

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _RateRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RateRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        '$label: $count',
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }
}