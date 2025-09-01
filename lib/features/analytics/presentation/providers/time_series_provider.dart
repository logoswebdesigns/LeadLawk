import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/time_series_data.dart';
import '../../data/repositories/analytics_repository.dart';
import 'analytics_providers.dart';
import 'dart:math' as math;

// Time range state provider
final selectedTimeRangeProvider = StateProvider<TimeRange>((ref) {
  return TimeRange.last30Days;
});

// Selected metrics provider
final selectedMetricsProvider = StateProvider<List<MetricType>>((ref) {
  return [
    MetricType.conversionRate,
    MetricType.callToConversionRatio,
  ];
});

// Chart options providers
final showGridProvider = StateProvider<bool>((ref) => true);
final showLegendProvider = StateProvider<bool>((ref) => true);
final enableTooltipProvider = StateProvider<bool>((ref) => true);
final showTrendLinesProvider = StateProvider<bool>((ref) => false);
final chartTypeProvider = StateProvider<ChartType>((ref) => ChartType.line);

// Time series data provider
final timeSeriesDataProvider = FutureProvider<List<TimeSeriesMetric>>((ref) async {
  final timeRange = ref.watch(selectedTimeRangeProvider);
  final selectedMetrics = ref.watch(selectedMetricsProvider);
  final repository = ref.watch(analyticsRepositoryProvider);
  
  // Generate data for selected metrics
  final metrics = <TimeSeriesMetric>[];
  
  for (final metricType in selectedMetrics) {
    final dataPoints = await _generateDataPoints(
      metricType,
      timeRange,
      repository,
    );
    
    metrics.add(TimeSeriesMetric(
      id: metricType.name,
      type: metricType,
      label: _getMetricLabel(metricType),
      dataPoints: dataPoints,
      color: _getMetricColor(metricType),
      preferredChartType: _getPreferredChartType(metricType),
      unit: _getMetricUnit(metricType),
      showTrendLine: ref.watch(showTrendLinesProvider),
    ));
  }
  
  return metrics;
});

Future<List<TimeSeriesDataPoint>> _generateDataPoints(
  MetricType metric,
  TimeRange timeRange,
  AnalyticsRepository repository,
) async {
  final points = <TimeSeriesDataPoint>[];
  final duration = timeRange.end.difference(timeRange.start);
  
  // Determine number of points based on granularity
  int numPoints;
  Duration interval;
  
  switch (timeRange.granularity) {
    case TimeGranularity.hourly:
      numPoints = duration.inHours;
      interval = const Duration(hours: 1);
      break;
    case TimeGranularity.daily:
      numPoints = duration.inDays;
      interval = const Duration(days: 1);
      break;
    case TimeGranularity.weekly:
      numPoints = (duration.inDays / 7).ceil();
      interval = const Duration(days: 7);
      break;
    case TimeGranularity.monthly:
      numPoints = (duration.inDays / 30).ceil();
      interval = const Duration(days: 30);
      break;
    case TimeGranularity.quarterly:
      numPoints = (duration.inDays / 90).ceil();
      interval = const Duration(days: 90);
      break;
  }
  
  // Generate data points with realistic patterns
  final random = math.Random(metric.index);
  double baseValue = _getBaseValue(metric);
  double trend = _getTrend(metric);
  
  for (int i = 0; i <= numPoints; i++) {
    final timestamp = timeRange.start.add(interval * i);
    if (timestamp.isAfter(timeRange.end)) break;
    
    // Add some randomness and trend
    final noise = (random.nextDouble() - 0.5) * baseValue * 0.2;
    final trendValue = trend * i;
    final value = math.max(0, baseValue + noise + trendValue);
    
    // Add weekly patterns for some metrics
    double weeklyPattern = 0;
    if (metric == MetricType.callVolume || metric == MetricType.newLeadsCount) {
      final dayOfWeek = timestamp.weekday;
      if (dayOfWeek == 6 || dayOfWeek == 7) {
        weeklyPattern = -baseValue * 0.3; // Lower on weekends
      } else if (dayOfWeek == 2 || dayOfWeek == 3) {
        weeklyPattern = baseValue * 0.2; // Higher mid-week
      }
    }
    
    points.add(TimeSeriesDataPoint(
      timestamp: timestamp,
      value: value + weeklyPattern,
      metadata: {
        'dayOfWeek': timestamp.weekday,
        'hour': timestamp.hour,
      },
    ));
  }
  
  return points;
}

double _getBaseValue(MetricType metric) {
  switch (metric) {
    case MetricType.conversionRate:
      return 0.15; // 15%
    case MetricType.callVolume:
      return 50;
    case MetricType.callToConversionRatio:
      return 0.25; // 25%
    case MetricType.averageCallDuration:
      return 180; // 3 minutes in seconds
    case MetricType.leadQualificationRate:
      return 0.40; // 40%
    case MetricType.websiteToNoWebsiteRatio:
      return 0.60; // 60% have websites
    case MetricType.newLeadsCount:
      return 30;
    case MetricType.followUpRate:
      return 0.70; // 70%
    case MetricType.responseRate:
      return 0.45; // 45%
    case MetricType.dncRate:
      return 0.05; // 5%
  }
}

double _getTrend(MetricType metric) {
  // Positive trends for good metrics, negative for bad
  switch (metric) {
    case MetricType.conversionRate:
      return 0.001; // Slight improvement
    case MetricType.callVolume:
      return 0.5; // Growing
    case MetricType.callToConversionRatio:
      return 0.002; // Improving
    case MetricType.averageCallDuration:
      return -1; // Getting more efficient
    case MetricType.leadQualificationRate:
      return 0.003; // Improving
    case MetricType.websiteToNoWebsiteRatio:
      return 0;
    case MetricType.newLeadsCount:
      return 0.8; // Growing
    case MetricType.followUpRate:
      return 0.001;
    case MetricType.responseRate:
      return 0.002;
    case MetricType.dncRate:
      return -0.0001; // Decreasing (good)
  }
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

Color _getMetricColor(MetricType metric) {
  switch (metric) {
    case MetricType.conversionRate:
      return const Color(0xFF00E5FF); // Cyan
    case MetricType.callVolume:
      return const Color(0xFF4ECDC4); // Teal
    case MetricType.callToConversionRatio:
      return const Color(0xFFFF6B6B); // Red
    case MetricType.averageCallDuration:
      return const Color(0xFFFFD93D); // Yellow
    case MetricType.leadQualificationRate:
      return const Color(0xFF95E1D3); // Mint
    case MetricType.websiteToNoWebsiteRatio:
      return const Color(0xFFA8E6CF); // Light Green
    case MetricType.newLeadsCount:
      return const Color(0xFF00E5FF); // Cyan
    case MetricType.followUpRate:
      return const Color(0xFFB4A7D6); // Lavender
    case MetricType.responseRate:
      return const Color(0xFFFFAB91); // Peach
    case MetricType.dncRate:
      return const Color(0xFFFF6B6B); // Red
  }
}

ChartType _getPreferredChartType(MetricType metric) {
  switch (metric) {
    case MetricType.callVolume:
    case MetricType.newLeadsCount:
      return ChartType.bar;
    case MetricType.conversionRate:
    case MetricType.callToConversionRatio:
    case MetricType.leadQualificationRate:
    case MetricType.websiteToNoWebsiteRatio:
    case MetricType.followUpRate:
    case MetricType.responseRate:
    case MetricType.dncRate:
      return ChartType.area;
    case MetricType.averageCallDuration:
      return ChartType.line;
  }
}

String? _getMetricUnit(MetricType metric) {
  switch (metric) {
    case MetricType.conversionRate:
    case MetricType.callToConversionRatio:
    case MetricType.leadQualificationRate:
    case MetricType.websiteToNoWebsiteRatio:
    case MetricType.followUpRate:
    case MetricType.responseRate:
    case MetricType.dncRate:
      return '%';
    case MetricType.averageCallDuration:
      return 'sec';
    case MetricType.callVolume:
    case MetricType.newLeadsCount:
      return null;
  }
}