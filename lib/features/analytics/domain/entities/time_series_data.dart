import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum MetricType {
  conversionRate,
  callVolume,
  callToConversionRatio,
  averageCallDuration,
  leadQualificationRate,
  websiteToNoWebsiteRatio,
  newLeadsCount,
  followUpRate,
  responseRate,
  dncRate,
}

enum TimeGranularity {
  hourly,
  daily,
  weekly,
  monthly,
  quarterly,
}

enum ChartType {
  line,
  area,
  bar,
  stackedArea,
  combo,
}

class TimeSeriesDataPoint extends Equatable {
  final DateTime timestamp;
  final double value;
  final Map<String, dynamic>? metadata;

  const TimeSeriesDataPoint({
    required this.timestamp,
    required this.value,
    this.metadata,
  });

  @override
  List<Object?> get props => [timestamp, value, metadata];
}

class TimeSeriesMetric extends Equatable {
  final String id;
  final MetricType type;
  final String label;
  final List<TimeSeriesDataPoint> dataPoints;
  final Color? color;
  final ChartType preferredChartType;
  final String? unit;
  final bool showTrendLine;

  const TimeSeriesMetric({
    required this.id,
    required this.type,
    required this.label,
    required this.dataPoints,
    this.color,
    this.preferredChartType = ChartType.line,
    this.unit,
    this.showTrendLine = false,
  });

  @override
  List<Object?> get props => [
        id,
        type,
        label,
        dataPoints,
        color,
        preferredChartType,
        unit,
        showTrendLine,
      ];

  TimeSeriesMetric copyWith({
    List<TimeSeriesDataPoint>? dataPoints,
    Color? color,
    ChartType? preferredChartType,
    bool? showTrendLine,
  }) {
    return TimeSeriesMetric(
      id: id,
      type: type,
      label: label,
      dataPoints: dataPoints ?? this.dataPoints,
      color: color ?? this.color,
      preferredChartType: preferredChartType ?? this.preferredChartType,
      unit: unit,
      showTrendLine: showTrendLine ?? this.showTrendLine,
    );
  }
}

class TimeRange extends Equatable {
  final DateTime start;
  final DateTime end;
  final TimeGranularity granularity;

  const TimeRange({
    required this.start,
    required this.end,
    required this.granularity,
  });

  @override
  List<Object> get props => [start, end, granularity];

  // Preset ranges
  static TimeRange get last24Hours => TimeRange(
        start: DateTime.now().subtract(const Duration(hours: 24)),
        end: DateTime.now(),
        granularity: TimeGranularity.hourly,
      );

  static TimeRange get last7Days => TimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
        granularity: TimeGranularity.daily,
      );

  static TimeRange get last30Days => TimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
        granularity: TimeGranularity.daily,
      );

  static TimeRange get last90Days => TimeRange(
        start: DateTime.now().subtract(const Duration(days: 90)),
        end: DateTime.now(),
        granularity: TimeGranularity.weekly,
      );

  static TimeRange get lastYear => TimeRange(
        start: DateTime.now().subtract(const Duration(days: 365)),
        end: DateTime.now(),
        granularity: TimeGranularity.monthly,
      );
}