// Distributed tracing for request tracking.
// Pattern: Correlation ID Pattern - trace across services.
// Single Responsibility: Track request flow.

import 'dart:math';
import 'structured_logger.dart';

/// Trace span
class TraceSpan {
  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final String operationName;
  final DateTime startTime;
  DateTime? endTime;
  final Map<String, dynamic> tags;
  final List<LogEntry> logs;
  TraceStatus status;
  
  TraceSpan({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    required this.operationName,
    required this.startTime,
    this.endTime,
    Map<String, dynamic>? tags,
    List<LogEntry>? logs,
    this.status = TraceStatus.inProgress,
  }) : tags = tags ?? {},
        logs = logs ?? [];
  
  Duration? get duration => endTime?.difference(startTime);
  
  Map<String, dynamic> toJson() => {
    'trace_id': traceId,
    'span_id': spanId,
    'parent_span_id': parentSpanId,
    'operation_name': operationName,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'duration_ms': duration?.inMilliseconds,
    'status': status.name,
    'tags': tags,
    'logs': logs.map((l) => l.toJson()).toList(),
  };
}

/// Trace status
enum TraceStatus {
  inProgress,
  success,
  error,
  cancelled,
}

/// Distributed tracer
class DistributedTracer {
  static final DistributedTracer _instance = DistributedTracer._internal();
  factory DistributedTracer() => _instance;
  DistributedTracer._internal();
  
  final Map<String, TraceSpan> _activeSpans = {};
  final Random _random = Random();
  final StructuredLogger _logger = StructuredLogger();
  
  /// Start a new trace
  String startTrace(String operationName, {Map<String, dynamic>? tags}) {
    final traceId = _generateId();
    final spanId = _generateId();
    
    final span = TraceSpan(
      traceId: traceId,
      spanId: spanId,
      operationName: operationName,
      startTime: DateTime.now(),
      tags: tags,
    );
    
    _activeSpans[spanId] = span;
    
    _logger.info('Trace started', fields: {
      'trace_id': traceId,
      'span_id': spanId,
      'operation': operationName,
    });
    
    return spanId;
  }
  
  /// Start a child span
  String startSpan(
    String parentSpanId,
    String operationName, {
    Map<String, dynamic>? tags,
  }) {
    final parent = _activeSpans[parentSpanId];
    if (parent == null) {
      throw StateError('Parent span not found: $parentSpanId');
    }
    
    final spanId = _generateId();
    
    final span = TraceSpan(
      traceId: parent.traceId,
      spanId: spanId,
      parentSpanId: parentSpanId,
      operationName: operationName,
      startTime: DateTime.now(),
      tags: tags,
    );
    
    _activeSpans[spanId] = span;
    
    return spanId;
  }
  
  /// End a span
  void endSpan(String spanId, {TraceStatus? status}) {
    final span = _activeSpans[spanId];
    if (span == null) return;
    
    span.endTime = DateTime.now();
    span.status = status ?? TraceStatus.success;
    
    _logger.info('Span ended', fields: span.toJson());
    
    _activeSpans.remove(spanId);
  }
  
  /// Generate unique ID
  String _generateId() {
    return _random.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  }
}