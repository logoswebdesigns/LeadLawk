import 'package:flutter/material.dart';
import '../../domain/entities/time_series_data.dart';

class MetricSelector extends StatelessWidget {
  final List<MetricType> selectedMetrics;
  final Function(List<MetricType>) onMetricsChanged;
  final List<MetricType> availableMetrics;

  const MetricSelector({
    super.key,
    required this.selectedMetrics,
    required this.onMetricsChanged,
    this.availableMetrics = MetricType.values,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2336),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Metrics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableMetrics.map((metric) {
              final isSelected = selectedMetrics.contains(metric);
              return FilterChip(
                label: Text(_getMetricLabel(metric)),
                selected: isSelected,
                onSelected: (selected) {
                  final newMetrics = List<MetricType>.from(selectedMetrics);
                  if (selected) {
                    newMetrics.add(metric);
                  } else {
                    newMetrics.remove(metric);
                  }
                  onMetricsChanged(newMetrics);
                },
                selectedColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                backgroundColor: const Color(0xFF2A3142),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                  fontSize: 12,
                ),
                checkmarkColor: const Color(0xFF00E5FF),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF00E5FF) : Colors.white24,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  onMetricsChanged(availableMetrics);
                },
                child: const Text(
                  'Select All',
                  style: TextStyle(color: Color(0xFF00E5FF)),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  onMetricsChanged([]);
                },
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getMetricLabel(MetricType metric) {
    switch (metric) {
      case MetricType.conversionRate:
        return 'Conversion Rate';
      case MetricType.callVolume:
        return 'Call Volume';
      case MetricType.callToConversionRatio:
        return 'Call to Conversion';
      case MetricType.averageCallDuration:
        return 'Avg Call Duration';
      case MetricType.leadQualificationRate:
        return 'Lead Qualification';
      case MetricType.websiteToNoWebsiteRatio:
        return 'Website Ratio';
      case MetricType.newLeadsCount:
        return 'New Leads';
      case MetricType.followUpRate:
        return 'Follow-up Rate';
      case MetricType.responseRate:
        return 'Response Rate';
      case MetricType.dncRate:
        return 'DNC Rate';
    }
  }
}

class TimeRangeSelector extends StatelessWidget {
  final TimeRange selectedRange;
  final Function(TimeRange) onRangeChanged;
  final bool showCustomRange;

  const TimeRangeSelector({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
    this.showCustomRange = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2336),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Time Range',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRangeButton(
                  'Last 24h',
                  TimeRange.last24Hours,
                  context,
                ),
                const SizedBox(width: 8),
                _buildRangeButton(
                  'Last 7d',
                  TimeRange.last7Days,
                  context,
                ),
                const SizedBox(width: 8),
                _buildRangeButton(
                  'Last 30d',
                  TimeRange.last30Days,
                  context,
                ),
                const SizedBox(width: 8),
                _buildRangeButton(
                  'Last 90d',
                  TimeRange.last90Days,
                  context,
                ),
                const SizedBox(width: 8),
                _buildRangeButton(
                  'Last Year',
                  TimeRange.lastYear,
                  context,
                ),
                if (showCustomRange) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showCustomRangePicker(context),
                    icon: Icon(Icons.refresh),
                    label: const Text('Custom'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.refresh),
              const SizedBox(width: 4),
              Text(
                'From: ${_formatDate(selectedRange.start)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 12),
              Text(
                'To: ${_formatDate(selectedRange.end)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeButton(String label, TimeRange range, BuildContext context) {
    final isSelected = _isRangeSelected(range);
    return OutlinedButton(
      onPressed: () => onRangeChanged(range),
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF00E5FF).withValues(alpha: 0.2) : null,
        foregroundColor: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
        side: BorderSide(
          color: isSelected ? const Color(0xFF00E5FF) : Colors.white24,
        ),
      ),
      child: Text(label),
    );
  }

  bool _isRangeSelected(TimeRange range) {
    return selectedRange.start.isAtSameMomentAs(range.start) &&
        selectedRange.end.isAtSameMomentAs(range.end) &&
        selectedRange.granularity == range.granularity;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _showCustomRangePicker(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: selectedRange.start,
        end: selectedRange.end,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Color(0xFF00E5FF),
              surface: Color(0xFF1E2336),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Determine appropriate granularity based on range
      final days = picked.end.difference(picked.start).inDays;
      TimeGranularity granularity;
      if (days <= 2) {
        granularity = TimeGranularity.hourly;
      } else if (days <= 30) {
        granularity = TimeGranularity.daily;
      } else if (days <= 90) {
        granularity = TimeGranularity.weekly;
      } else {
        granularity = TimeGranularity.monthly;
      }

      onRangeChanged(TimeRange(
        start: picked.start,
        end: picked.end,
        granularity: granularity,
      ));
    }
  }
}

class ChartOptionsPanel extends StatelessWidget {
  final bool showGrid;
  final bool showLegend;
  final bool enableTooltip;
  final bool showTrendLines;
  final ChartType chartType;
  final Function(bool) onShowGridChanged;
  final Function(bool) onShowLegendChanged;
  final Function(bool) onEnableTooltipChanged;
  final Function(bool) onShowTrendLinesChanged;
  final Function(ChartType) onChartTypeChanged;

  const ChartOptionsPanel({
    super.key,
    required this.showGrid,
    required this.showLegend,
    required this.enableTooltip,
    required this.showTrendLines,
    required this.chartType,
    required this.onShowGridChanged,
    required this.onShowLegendChanged,
    required this.onEnableTooltipChanged,
    required this.onShowTrendLinesChanged,
    required this.onChartTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2336),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chart Options',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  title: const Text(
                    'Grid',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  value: showGrid,
                  onChanged: onShowGridChanged,
                  activeColor: const Color(0xFF00E5FF),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  title: const Text(
                    'Legend',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  value: showLegend,
                  onChanged: onShowLegendChanged,
                  activeColor: const Color(0xFF00E5FF),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  title: const Text(
                    'Tooltip',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  value: enableTooltip,
                  onChanged: onEnableTooltipChanged,
                  activeColor: const Color(0xFF00E5FF),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  title: const Text(
                    'Trends',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  value: showTrendLines,
                  onChanged: onShowTrendLinesChanged,
                  activeColor: const Color(0xFF00E5FF),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Chart Type',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ChartType.values.map((type) {
                final isSelected = chartType == type;
                return Padding(padding: EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_getChartTypeLabel(type)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) onChartTypeChanged(type);
                    },
                    selectedColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                    backgroundColor: const Color(0xFF2A3142),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getChartTypeLabel(ChartType type) {
    switch (type) {
      case ChartType.line:
        return 'Line';
      case ChartType.area:
        return 'Area';
      case ChartType.bar:
        return 'Bar';
      case ChartType.stackedArea:
        return 'Stacked';
      case ChartType.combo:
        return 'Combo';
    }
  }
}