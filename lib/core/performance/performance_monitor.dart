// Performance monitoring and metrics.
// Pattern: Observer Pattern for performance tracking.
// Single Responsibility: Performance measurement and reporting.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';

/// Performance monitor for tracking app metrics
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();
  
  final Map<String, Stopwatch> _timers = {};
  final Map<String, List<Duration>> _metrics = {};
  final List<FrameTiming> _frameTimings = [];
  bool _isMonitoring = false;
  
  /// Start monitoring
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    
    // Monitor frame timings
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }
  
  /// Stop monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
  }
  
  /// Start timing an operation
  void startTimer(String operationName) {
    _timers[operationName] = Stopwatch()..start();
  }
  
  /// End timing an operation
  Duration? endTimer(String operationName) {
    final stopwatch = _timers.remove(operationName);
    if (stopwatch == null) return null;
    
    stopwatch.stop();
    final duration = stopwatch.elapsed;
    
    // Store metric
    _metrics.putIfAbsent(operationName, () => []).add(duration);
    
    return duration;
  }
  
  /// Time an async operation
  Future<T> timeAsync<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    startTimer(operationName);
    try {
      return await operation();
    } finally {
      endTimer(operationName);
    }
  }
  
  /// Time a sync operation
  T timeSync<T>(
    String operationName,
    T Function() operation,
  ) {
    startTimer(operationName);
    try {
      return operation();
    } finally {
      endTimer(operationName);
    }
  }
  
  void _onFrameTimings(List<FrameTiming> timings) {
    _frameTimings.addAll(timings);
    
    // Keep only recent timings
    if (_frameTimings.length > 1000) {
      _frameTimings.removeRange(0, _frameTimings.length - 1000);
    }
  }
  
  /// Get performance metrics
  PerformanceMetrics getMetrics() {
    return PerformanceMetrics(
      frameMetrics: _calculateFrameMetrics(),
      operationMetrics: _calculateOperationMetrics(),
      memoryMetrics: _getMemoryMetrics(),
    );
  }
  
  FrameMetrics _calculateFrameMetrics() {
    if (_frameTimings.isEmpty) {
      return FrameMetrics.empty();
    }
    
    final buildTimes = _frameTimings
        .map((t) => t.buildDuration)
        .toList();
    final rasterTimes = _frameTimings
        .map((t) => t.rasterDuration)
        .toList();
    
    return FrameMetrics(
      averageBuildTime: _calculateAverage(buildTimes),
      averageRasterTime: _calculateAverage(rasterTimes),
      totalFrames: _frameTimings.length,
      droppedFrames: _frameTimings
          .where((t) => t.totalSpan > Duration(milliseconds: 16))
          .length,
    );
  }
  
  Map<String, OperationMetric> _calculateOperationMetrics() {
    final metrics = <String, OperationMetric>{};
    
    for (final entry in _metrics.entries) {
      final durations = entry.value;
      if (durations.isEmpty) continue;
      
      metrics[entry.key] = OperationMetric(
        count: durations.length,
        totalTime: durations.reduce((a, b) => a + b),
        averageTime: _calculateAverage(durations),
        minTime: durations.reduce((a, b) => a < b ? a : b),
        maxTime: durations.reduce((a, b) => a > b ? a : b),
      );
    }
    
    return metrics;
  }
  
  MemoryMetrics _getMemoryMetrics() {
    // Note: In production, use more sophisticated memory tracking
    return MemoryMetrics(
      currentUsage: 0,
      peakUsage: 0,
    );
  }
  
  Duration _calculateAverage(List<Duration> durations) {
    if (durations.isEmpty) return Duration.zero;
    
    final totalMicroseconds = durations
        .map((d) => d.inMicroseconds)
        .reduce((a, b) => a + b);
    
    return Duration(
      microseconds: totalMicroseconds ~/ durations.length,
    );
  }
  
  /// Clear all metrics
  void clearMetrics() {
    _timers.clear();
    _metrics.clear();
    _frameTimings.clear();
  }
}

/// Performance metrics data
class PerformanceMetrics {
  final FrameMetrics frameMetrics;
  final Map<String, OperationMetric> operationMetrics;
  final MemoryMetrics memoryMetrics;
  
  const PerformanceMetrics({
    required this.frameMetrics,
    required this.operationMetrics,
    required this.memoryMetrics,
  });
}

/// Frame performance metrics
class FrameMetrics {
  final Duration averageBuildTime;
  final Duration averageRasterTime;
  final int totalFrames;
  final int droppedFrames;
  
  const FrameMetrics({
    required this.averageBuildTime,
    required this.averageRasterTime,
    required this.totalFrames,
    required this.droppedFrames,
  });
  
  factory FrameMetrics.empty() => FrameMetrics(
    averageBuildTime: Duration.zero,
    averageRasterTime: Duration.zero,
    totalFrames: 0,
    droppedFrames: 0,
  );
  
  double get fps => totalFrames > 0 
    ? 1000 / (averageBuildTime + averageRasterTime).inMilliseconds
    : 0;
  
  double get droppedFramePercentage => totalFrames > 0
    ? (droppedFrames / totalFrames) * 100
    : 0;
}

/// Operation performance metric
class OperationMetric {
  final int count;
  final Duration totalTime;
  final Duration averageTime;
  final Duration minTime;
  final Duration maxTime;
  
  const OperationMetric({
    required this.count,
    required this.totalTime,
    required this.averageTime,
    required this.minTime,
    required this.maxTime,
  });
}

/// Memory metrics
class MemoryMetrics {
  final int currentUsage;
  final int peakUsage;
  
  const MemoryMetrics({
    required this.currentUsage,
    required this.peakUsage,
  });
}

/// Performance overlay widget
class PerformanceOverlay extends StatefulWidget {
  final Widget child;
  final bool showFPS;
  final bool showMemory;
  final bool showOperations;
  
  const PerformanceOverlay({
    super.key,
    required this.child,
    this.showFPS = true,
    this.showMemory = false,
    this.showOperations = false,
  });
  
  @override
  State<PerformanceOverlay> createState() => _PerformanceOverlayState();
}

class _PerformanceOverlayState extends State<PerformanceOverlay> {
  Timer? _updateTimer;
  PerformanceMetrics? _metrics;
  
  @override
  void initState() {
    super.initState();
    PerformanceMonitor().startMonitoring();
    _updateTimer = Timer.periodic(
      Duration(seconds: 1),
      (_) => _updateMetrics(),
    );
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
  
  void _updateMetrics() {
    if (mounted) {
      setState(() {
        _metrics = PerformanceMonitor().getMetrics();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_metrics != null)
          Positioned(
            top: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.all(8),
                color: Colors.black54,
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.showFPS)
                        Text('FPS: ${_metrics!.frameMetrics.fps.toStringAsFixed(1)}'),
                      if (widget.showFPS)
                        Text('Dropped: ${_metrics!.frameMetrics.droppedFramePercentage.toStringAsFixed(1)}%'),
                      if (widget.showMemory)
                        Text('Memory: ${_metrics!.memoryMetrics.currentUsage ~/ 1024 ~/ 1024}MB'),
                      if (widget.showOperations)
                        ..._metrics!.operationMetrics.entries.take(3).map((e) =>
                          Text('${e.key}: ${e.value.averageTime.inMilliseconds}ms'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Performance logger
class PerformanceLogger {
  static void log(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      debugPrint('[PERF] $message');
      if (data != null) {
        data.forEach((key, value) {
          debugPrint('  $key: $value');
        });
      }
    }
  }
  
  static void logMetrics(PerformanceMetrics metrics) {
    log('Performance Metrics', data: {
      'FPS': metrics.frameMetrics.fps.toStringAsFixed(1),
      'Dropped Frames': '${metrics.frameMetrics.droppedFramePercentage.toStringAsFixed(1)}%',
      'Operations': metrics.operationMetrics.length,
    });
  }
}