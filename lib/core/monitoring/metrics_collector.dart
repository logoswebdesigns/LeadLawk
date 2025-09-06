// Metrics collection for performance monitoring.
// Pattern: Metrics Aggregation Pattern.
// Single Responsibility: Collect and aggregate metrics.

import 'dart:async';
import 'structured_logger.dart';

/// Metric types
enum MetricType {
  counter,
  gauge,
  histogram,
  timer,
}

/// Metric data point
class MetricDataPoint {
  final String name;
  final MetricType type;
  final double value;
  final DateTime timestamp;
  final Map<String, String> tags;
  
  MetricDataPoint({
    required this.name,
    required this.type,
    required this.value,
    required this.timestamp,
    Map<String, String>? tags,
  }) : tags = tags ?? {};
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.name,
    'value': value,
    'timestamp': timestamp.toIso8601String(),
    'tags': tags,
  };
}

/// Metrics collector
class MetricsCollector {
  static final MetricsCollector _instance = MetricsCollector._internal();
  factory MetricsCollector() => _instance;
  MetricsCollector._internal();
  
  final Map<String, double> _counters = {};
  final Map<String, double> _gauges = {};
  final Map<String, List<double>> _histograms = {};
  final StructuredLogger _logger = StructuredLogger();
  Timer? _reportTimer;
  
  /// Initialize metrics collection
  void initialize({Duration reportInterval = const Duration(minutes: 1)}) {
    _reportTimer?.cancel();
    _reportTimer = Timer.periodic(reportInterval, (_) => _reportMetrics());
  }
  
  /// Increment a counter
  void incrementCounter(String name, {double value = 1, Map<String, String>? tags}) {
    final key = _getKey(name, tags);
    _counters[key] = (_counters[key] ?? 0) + value;
    
    _emit(MetricDataPoint(
      name: name,
      type: MetricType.counter,
      value: _counters[key]!,
      timestamp: DateTime.now(),
      tags: tags,
    ));
  }
  
  /// Set a gauge value
  void setGauge(String name, double value, {Map<String, String>? tags}) {
    final key = _getKey(name, tags);
    _gauges[key] = value;
    
    _emit(MetricDataPoint(
      name: name,
      type: MetricType.gauge,
      value: value,
      timestamp: DateTime.now(),
      tags: tags,
    ));
  }
  
  /// Record a histogram value
  void recordHistogram(String name, double value, {Map<String, String>? tags}) {
    final key = _getKey(name, tags);
    _histograms.putIfAbsent(key, () => []).add(value);
    
    _emit(MetricDataPoint(
      name: name,
      type: MetricType.histogram,
      value: value,
      timestamp: DateTime.now(),
      tags: tags,
    ));
  }
  
  /// Time an operation
  Future<T> timeOperation<T>(
    String name,
    Future<T> Function() operation, {
    Map<String, String>? tags,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await operation();
    } finally {
      stopwatch.stop();
      recordHistogram(
        name,
        stopwatch.elapsedMilliseconds.toDouble(),
        tags: tags,
      );
    }
  }
  
  /// Get key for metric
  String _getKey(String name, Map<String, String>? tags) {
    if (tags == null || tags.isEmpty) return name;
    final tagStr = tags.entries.map((e) => '${e.key}=${e.value}').join(',');
    return '$name{$tagStr}';
  }
  
  /// Emit metric
  void _emit(MetricDataPoint point) {
    _logger.debug('Metric recorded', fields: point.toJson());
  }
  
  /// Report aggregated metrics
  void _reportMetrics() {
    // Report counters
    _counters.forEach((key, value) {
      _logger.info('Counter metric', fields: {'metric': key, 'value': value});
    });
    
    // Report gauges
    _gauges.forEach((key, value) {
      _logger.info('Gauge metric', fields: {'metric': key, 'value': value});
    });
    
    // Report histogram summaries
    _histograms.forEach((key, values) {
      if (values.isEmpty) return;
      
      final stats = _calculateStats(values);
      _logger.info('Histogram metric', fields: {
        'metric': key,
        ...stats,
      });
    });
  }
  
  /// Calculate statistics
  Map<String, dynamic> _calculateStats(List<double> values) {
    values.sort();
    final sum = values.reduce((a, b) => a + b);
    final mean = sum / values.length;
    
    return {
      'count': values.length,
      'sum': sum,
      'mean': mean,
      'min': values.first,
      'max': values.last,
      'p50': _percentile(values, 0.5),
      'p95': _percentile(values, 0.95),
      'p99': _percentile(values, 0.99),
    };
  }
  
  /// Calculate percentile
  double _percentile(List<double> sorted, double p) {
    final index = (sorted.length * p).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}