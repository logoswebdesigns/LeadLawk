import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/entities/time_series_data.dart';
import 'dart:math' as math;

class FlexibleTimeSeriesChart extends StatefulWidget {
  final List<TimeSeriesMetric> metrics;
  final TimeRange timeRange;
  final double height;
  final bool showGrid;
  final bool showLegend;
  final bool enableTooltip;
  final bool enableZoom;
  final Function(DateTime)? onPointSelected;

  const FlexibleTimeSeriesChart({
    super.key,
    required this.metrics,
    required this.timeRange,
    this.height = 300,
    this.showGrid = true,
    this.showLegend = true,
    this.enableTooltip = true,
    this.enableZoom = false,
    this.onPointSelected,
  });

  @override
  State<FlexibleTimeSeriesChart> createState() => _FlexibleTimeSeriesChartState();
}

class _FlexibleTimeSeriesChartState extends State<FlexibleTimeSeriesChart> {
  late double minX;
  late double maxX;
  late double minY;
  late double maxY;
  int? touchedIndex;

  @override
  void initState() {
    super.initState();
    _calculateBounds();
  }

  @override
  void didUpdateWidget(FlexibleTimeSeriesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metrics != widget.metrics || oldWidget.timeRange != widget.timeRange) {
      _calculateBounds();
    }
  }

  void _calculateBounds() {
    if (widget.metrics.isEmpty) {
      minX = 0;
      maxX = 1;
      minY = 0;
      maxY = 1;
      return;
    }

    minX = widget.timeRange.start.millisecondsSinceEpoch.toDouble();
    maxX = widget.timeRange.end.millisecondsSinceEpoch.toDouble();

    double tempMinY = double.infinity;
    double tempMaxY = double.negativeInfinity;

    for (final metric in widget.metrics) {
      for (final point in metric.dataPoints) {
        tempMinY = math.min(tempMinY, point.value);
        tempMaxY = math.max(tempMaxY, point.value);
      }
    }

    // Add padding to Y axis
    final yPadding = (tempMaxY - tempMinY) * 0.1;
    minY = math.max(0, tempMinY - yPadding);
    maxY = tempMaxY + yPadding;

    if (minY == maxY) {
      minY = minY - 1;
      maxY = maxY + 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.metrics.isEmpty) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFF1E2336),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No data available',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2336),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (widget.showLegend) _buildLegend(),
          Expanded(
            child: LineChart(
              _buildChartData(),
              duration: const Duration(milliseconds: 300),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: widget.metrics.map((metric) {
          final color = metric.color ?? _getDefaultColor(widget.metrics.indexOf(metric));
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  metric.label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                if (metric.unit != null) ...[
                  const SizedBox(width: 2),
                  Text(
                    '(${metric.unit})',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  LineChartData _buildChartData() {
    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: widget.showGrid,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.white10,
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: Colors.white10,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return Text(
                _formatYValue(value),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              return Text(
                _formatXValue(value),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.white12),
      ),
      lineBarsData: _buildLineBars(),
      lineTouchData: widget.enableTooltip
          ? LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: const Color(0xFF2A3142),
                tooltipRoundedRadius: 8,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final metric = widget.metrics[spot.barIndex];
                    final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                    return LineTooltipItem(
                      '${metric.label}\n',
                      const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: '${_formatYValue(spot.y)}${metric.unit ?? ''}',
                          style: TextStyle(
                            color: metric.color ?? _getDefaultColor(spot.barIndex),
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: '\n${_formatDate(date)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
              ),
              handleBuiltInTouches: true,
            )
          : LineTouchData(enabled: false),
    );
  }

  List<LineChartBarData> _buildLineBars() {
    return widget.metrics.asMap().entries.map((entry) {
      final index = entry.key;
      final metric = entry.value;
      final color = metric.color ?? _getDefaultColor(index);

      final spots = metric.dataPoints.map((point) {
        return FlSpot(
          point.timestamp.millisecondsSinceEpoch.toDouble(),
          point.value,
        );
      }).toList();

      // Sort spots by X value to ensure proper line drawing
      spots.sort((a, b) => a.x.compareTo(b.x));

      final isArea = metric.preferredChartType == ChartType.area ||
          metric.preferredChartType == ChartType.stackedArea;

      return LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.3,
        color: color,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: spots.length <= 20,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 3,
              color: color,
              strokeWidth: 1,
              strokeColor: Colors.white,
            );
          },
        ),
        belowBarData: isArea
            ? BarAreaData(
                show: true,
                color: color.withOpacity(0.2),
              )
            : BarAreaData(show: false),
        showingIndicators: metric.showTrendLine ? _calculateTrendLine(spots) : [],
      );
    }).toList();
  }

  List<int> _calculateTrendLine(List<FlSpot> spots) {
    // Simple linear regression for trend line
    if (spots.length < 2) return [];

    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (final spot in spots) {
      sumX += spot.x;
      sumY += spot.y;
      sumXY += spot.x * spot.y;
      sumX2 += spot.x * spot.x;
    }

    final n = spots.length;
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    // Return indices for first and last points of trend line
    return [0, spots.length - 1];
  }

  String _formatYValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else if (value < 1 && value > 0) {
      return '${(value * 100).toStringAsFixed(0)}%';
    }
    return value.toStringAsFixed(0);
  }

  String _formatXValue(double value) {
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    switch (widget.timeRange.granularity) {
      case TimeGranularity.hourly:
        return '${date.hour}:00';
      case TimeGranularity.daily:
        return '${date.month}/${date.day}';
      case TimeGranularity.weekly:
        return '${date.month}/${date.day}';
      case TimeGranularity.monthly:
        return '${_getMonthAbbr(date.month)}';
      case TimeGranularity.quarterly:
        return 'Q${((date.month - 1) ~/ 3) + 1}';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Color _getDefaultColor(int index) {
    const colors = [
      Color(0xFF00E5FF),
      Color(0xFFFF6B6B),
      Color(0xFF4ECDC4),
      Color(0xFFFFD93D),
      Color(0xFF95E1D3),
      Color(0xFFA8E6CF),
    ];
    return colors[index % colors.length];
  }
}