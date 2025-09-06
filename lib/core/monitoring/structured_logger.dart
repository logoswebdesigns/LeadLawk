// Structured logging system for observability.
// Pattern: Structured Logging - machine-readable logs.
// Single Responsibility: Emit structured log events.

import 'package:flutter/foundation.dart';

/// Log levels
enum LogLevel {
  trace,
  debug,
  info,
  warning,
  error,
  fatal,
}

/// Structured log entry
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final Map<String, dynamic> fields;
  final String? correlationId;
  final String? spanId;
  final String? traceId;
  
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    Map<String, dynamic>? fields,
    this.correlationId,
    this.spanId,
    this.traceId,
  }) : fields = fields ?? {};
  
  Map<String, dynamic> toJson() => {
    '@timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'message': message,
    'correlation_id': correlationId,
    'span_id': spanId,
    'trace_id': traceId,
    ...fields,
  };
}

/// Structured logger
class StructuredLogger {
  static final StructuredLogger _instance = StructuredLogger._internal();
  factory StructuredLogger() => _instance;
  StructuredLogger._internal();
  
  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  final List<LogSink> _sinks = [];
  
  /// Configure minimum log level
  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }
  
  /// Add a log sink
  void addSink(LogSink sink) {
    _sinks.add(sink);
  }
  
  /// Log a message
  void log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? fields,
    String? correlationId,
    String? spanId,
    String? traceId,
  }) {
    if (level.index < _minLevel.index) return;
    
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      fields: fields,
      correlationId: correlationId,
      spanId: spanId,
      traceId: traceId,
    );
    
    for (final sink in _sinks) {
      sink.write(entry);
    }
  }
  
  // Convenience methods
  void trace(String message, {Map<String, dynamic>? fields}) =>
      log(LogLevel.trace, message, fields: fields);
  
  void debug(String message, {Map<String, dynamic>? fields}) =>
      log(LogLevel.debug, message, fields: fields);
  
  void info(String message, {Map<String, dynamic>? fields}) =>
      log(LogLevel.info, message, fields: fields);
  
  void warning(String message, {Map<String, dynamic>? fields}) =>
      log(LogLevel.warning, message, fields: fields);
  
  void error(String message, {Map<String, dynamic>? fields}) =>
      log(LogLevel.error, message, fields: fields);
  
  void fatal(String message, {Map<String, dynamic>? fields}) =>
      log(LogLevel.fatal, message, fields: fields);
}

/// Log sink interface
abstract class LogSink {
  void write(LogEntry entry);
}