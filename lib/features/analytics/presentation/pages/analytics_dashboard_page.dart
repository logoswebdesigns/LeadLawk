import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/flexible_time_series_chart.dart';
import '../widgets/analytics_controls.dart';
import '../providers/time_series_provider.dart';
import '../../domain/entities/time_series_data.dart';

class AnalyticsDashboardPage extends ConsumerStatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  ConsumerState<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends ConsumerState<AnalyticsDashboardPage> {
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    final timeSeriesData = ref.watch(timeSeriesDataProvider);
    final selectedTimeRange = ref.watch(selectedTimeRangeProvider);
    final selectedMetrics = ref.watch(selectedMetricsProvider);
    final showGrid = ref.watch(showGridProvider);
    final showLegend = ref.watch(showLegendProvider);
    final enableTooltip = ref.watch(enableTooltipProvider);
    final showTrendLines = ref.watch(showTrendLinesProvider);
    final chartType = ref.watch(chartTypeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E27),
        title: const Text(
          'Analytics Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showControls ? Icons.tune : Icons.tune_outlined,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            tooltip: 'Toggle Controls',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              ref.invalidate(timeSeriesDataProvider);
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Row(
        children: [
          // Controls Panel
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _showControls ? 350 : 0,
            child: _showControls
                ? Container(
                    color: const Color(0xFF0D1117),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time Range Selector
                          TimeRangeSelector(
                            selectedRange: selectedTimeRange,
                            onRangeChanged: (range) {
                              ref.read(selectedTimeRangeProvider.notifier).state = range;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Metric Selector
                          MetricSelector(
                            selectedMetrics: selectedMetrics,
                            onMetricsChanged: (metrics) {
                              ref.read(selectedMetricsProvider.notifier).state = metrics;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Chart Options
                          ChartOptionsPanel(
                            showGrid: showGrid,
                            showLegend: showLegend,
                            enableTooltip: enableTooltip,
                            showTrendLines: showTrendLines,
                            chartType: chartType,
                            onShowGridChanged: (value) {
                              ref.read(showGridProvider.notifier).state = value;
                            },
                            onShowLegendChanged: (value) {
                              ref.read(showLegendProvider.notifier).state = value;
                            },
                            onEnableTooltipChanged: (value) {
                              ref.read(enableTooltipProvider.notifier).state = value;
                            },
                            onShowTrendLinesChanged: (value) {
                              ref.read(showTrendLinesProvider.notifier).state = value;
                            },
                            onChartTypeChanged: (type) {
                              ref.read(chartTypeProvider.notifier).state = type;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Quick Actions
                          _buildQuickActions(),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          
          // Main Chart Area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 24),
                  
                  // Chart
                  Expanded(
                    child: timeSeriesData.when(
                      data: (metrics) {
                        if (metrics.isEmpty) {
                          return _buildEmptyState();
                        }
                        
                        return FlexibleTimeSeriesChart(
                          metrics: metrics,
                          timeRange: selectedTimeRange,
                          showGrid: showGrid,
                          showLegend: showLegend,
                          enableTooltip: enableTooltip,
                          height: double.infinity,
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                      error: (error, stack) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading data',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              error.toString(),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Insights
                  const SizedBox(height: 24),
                  _buildInsights(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final selectedMetrics = ref.watch(selectedMetricsProvider);
    final selectedTimeRange = ref.watch(selectedTimeRangeProvider);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${selectedMetrics.length} Metric${selectedMetrics.length != 1 ? 's' : ''} Selected',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimeRange(selectedTimeRange),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildQuickMetricButton(
              'Conversion',
              MetricType.conversionRate,
              Icons.trending_up,
            ),
            const SizedBox(width: 8),
            _buildQuickMetricButton(
              'Calls',
              MetricType.callVolume,
              Icons.phone_in_talk,
            ),
            const SizedBox(width: 8),
            _buildQuickMetricButton(
              'Leads',
              MetricType.newLeadsCount,
              Icons.people,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickMetricButton(String label, MetricType metric, IconData icon) {
    final selectedMetrics = ref.watch(selectedMetricsProvider);
    final isSelected = selectedMetrics.contains(metric);
    
    return OutlinedButton.icon(
      onPressed: () {
        final current = ref.read(selectedMetricsProvider);
        if (isSelected) {
          ref.read(selectedMetricsProvider.notifier).state = 
            current.where((m) => m != metric).toList();
        } else {
          ref.read(selectedMetricsProvider.notifier).state = [...current, metric];
        }
      },
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF00E5FF).withOpacity(0.2) : null,
        foregroundColor: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
        side: BorderSide(
          color: isSelected ? const Color(0xFF00E5FF) : Colors.white24,
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2336),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Cold Calling Performance',
            Icons.phone_callback,
            () {
              ref.read(selectedMetricsProvider.notifier).state = [
                MetricType.callVolume,
                MetricType.conversionRate,
                MetricType.callToConversionRatio,
              ];
            },
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            'Lead Generation',
            Icons.person_add,
            () {
              ref.read(selectedMetricsProvider.notifier).state = [
                MetricType.newLeadsCount,
                MetricType.leadQualificationRate,
                MetricType.websiteToNoWebsiteRatio,
              ];
            },
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            'Response Metrics',
            Icons.chat_bubble,
            () {
              ref.read(selectedMetricsProvider.notifier).state = [
                MetricType.responseRate,
                MetricType.followUpRate,
                MetricType.dncRate,
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildInsights() {
    final timeSeriesData = ref.watch(timeSeriesDataProvider);
    
    return timeSeriesData.maybeWhen(
      data: (metrics) {
        if (metrics.isEmpty) return const SizedBox.shrink();
        
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E2336),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Key Insights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...metrics.take(3).map((metric) {
                final trend = _calculateTrend(metric.dataPoints);
                final average = _calculateAverage(metric.dataPoints);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: metric.color ?? const Color(0xFF00E5FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          metric.label,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        'Avg: ${_formatValue(average, metric.unit)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        trend > 0 ? Icons.trending_up : Icons.trending_down,
                        color: trend > 0 ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${trend.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: trend > 0 ? Colors.green : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.analytics_outlined,
            color: Colors.white24,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No metrics selected',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select metrics from the control panel to view data',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeRange(TimeRange range) {
    final formatter = MaterialLocalizations.of(context).formatMediumDate;
    return '${formatter(range.start)} - ${formatter(range.end)}';
  }

  double _calculateTrend(List<TimeSeriesDataPoint> points) {
    if (points.length < 2) return 0;
    
    final firstHalf = points.take(points.length ~/ 2).toList();
    final secondHalf = points.skip(points.length ~/ 2).toList();
    
    final firstAvg = _calculateAverage(firstHalf);
    final secondAvg = _calculateAverage(secondHalf);
    
    if (firstAvg == 0) return 0;
    return ((secondAvg - firstAvg) / firstAvg) * 100;
  }

  double _calculateAverage(List<TimeSeriesDataPoint> points) {
    if (points.isEmpty) return 0;
    final sum = points.fold<double>(0, (sum, point) => sum + point.value);
    return sum / points.length;
  }

  String _formatValue(double value, String? unit) {
    if (unit == '%') {
      return '${(value * 100).toStringAsFixed(1)}%';
    } else if (unit == 'sec') {
      final minutes = (value / 60).floor();
      final seconds = (value % 60).floor();
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      return value.toStringAsFixed(1);
    }
  }
}