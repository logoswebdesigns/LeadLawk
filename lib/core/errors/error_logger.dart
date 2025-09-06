// Error logging system.
// Pattern: Structured Logging - consistent error tracking.
// Single Responsibility: Log errors with context.

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'app_exceptions.dart';

/// Error log entry
class ErrorLogEntry {
  final DateTime timestamp;
  final AppException exception;
  final StackTrace? stackTrace;
  final Map<String, dynamic> context;
  final String? userId;
  final String? sessionId;
  
  ErrorLogEntry({
    required this.timestamp,
    required this.exception,
    this.stackTrace,
    Map<String, dynamic>? context,
    this.userId,
    this.sessionId,
  }) : context = context ?? {};
  
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'exception_type': exception.runtimeType.toString(),
    'message': exception.message,
    'code': exception.code,
    'severity': exception.severity.name,
    'user_id': userId,
    'session_id': sessionId,
    'context': context,
    'stack_trace': stackTrace?.toString(),
  };
}

/// Error logger
class ErrorLogger {
  static final ErrorLogger _instance = ErrorLogger._internal();
  factory ErrorLogger() => _instance;
  ErrorLogger._internal();
  
  final Queue<ErrorLogEntry> _errorQueue = Queue<ErrorLogEntry>();
  final int _maxQueueSize = 100;
  
  String? _currentUserId;
  String? _currentSessionId;
  final Map<String, dynamic> _globalContext = {};
  
  Timer? _flushTimer;
  final Duration _flushInterval = const Duration(minutes: 5);
  
  /// Initialize logger
  void initialize({
    String? userId,
    String? sessionId,
    Map<String, dynamic>? globalContext,
  }) {
    _currentUserId = userId;
    _currentSessionId = sessionId;
    if (globalContext != null) {
      _globalContext.addAll(globalContext);
    }
    
    // Start periodic flush
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => flush());
  }
  
  /// Update user context
  void setUser(String? userId) {
    _currentUserId = userId;
  }
  
  /// Update session
  void setSession(String? sessionId) {
    _currentSessionId = sessionId;
  }
  
  /// Add global context
  void addGlobalContext(String key, dynamic value) {
    _globalContext[key] = value;
  }
  
  /// Log an error
  Future<void> logError(
    AppException exception,
    StackTrace? stackTrace, {
    Map<String, dynamic>? context,
  }) async {
    final entry = ErrorLogEntry(
      timestamp: DateTime.now(),
      exception: exception,
      stackTrace: stackTrace,
      context: {..._globalContext, ...?context},
      userId: _currentUserId,
      sessionId: _currentSessionId,
    );
    
    _addToQueue(entry);
    
    // Log to console in debug mode
    if (kDebugMode) {
      _logToConsole(entry);
    }
    
    // Flush immediately for critical errors
    if (exception.severity == ErrorSeverity.critical) {
      await flush();
    }
  }
  
  /// Add entry to queue
  void _addToQueue(ErrorLogEntry entry) {
    _errorQueue.add(entry);
    
    // Maintain queue size
    while (_errorQueue.length > _maxQueueSize) {
      _errorQueue.removeFirst();
    }
  }
  
  /// Log to console
  void _logToConsole(ErrorLogEntry entry) {
    final buffer = StringBuffer();
    
    buffer.writeln('┌─────────────────────────────────────────────────────────');
    buffer.writeln('│ ERROR: ${entry.exception.runtimeType}');
    buffer.writeln('├─────────────────────────────────────────────────────────');
    buffer.writeln('│ Time: ${entry.timestamp.toIso8601String()}');
    buffer.writeln('│ Severity: ${entry.exception.severity.name.toUpperCase()}');
    buffer.writeln('│ Message: ${entry.exception.message}');
    
    if (entry.exception.code != null) {
      buffer.writeln('│ Code: ${entry.exception.code}');
    }
    
    if (entry.userId != null) {
      buffer.writeln('│ User: ${entry.userId}');
    }
    
    if (entry.context.isNotEmpty) {
      buffer.writeln('│ Context:');
      entry.context.forEach((key, value) {
        buffer.writeln('│   $key: $value');
      });
    }
    
    if (entry.stackTrace != null) {
      buffer.writeln('├─────────────────────────────────────────────────────────');
      buffer.writeln('│ Stack Trace:');
      buffer.writeln('│ ${entry.stackTrace.toString().split('\n').join('\n│ ')}');
    }
    
    buffer.writeln('└─────────────────────────────────────────────────────────');
    
    debugPrint(buffer.toString());
  }
  
  /// Flush logs to persistent storage or remote service
  Future<void> flush() async {
    if (_errorQueue.isEmpty) return;
    
    final errors = List<ErrorLogEntry>.from(_errorQueue);
    _errorQueue.clear();
    
    try {
      // In production, send to logging service
      await _sendToLoggingService(errors);
      
      // Also save locally for offline access
      await _saveLocally(errors);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to flush error logs: $e');
      }
      // Re-add errors to queue if flush failed
      _errorQueue.addAll(errors);
    }
  }
  
  /// Send logs to remote service
  Future<void> _sendToLoggingService(List<ErrorLogEntry> entries) async {
    // TODO: Implement remote logging service integration
    // For now, just simulate async operation
    await Future.delayed(Duration(milliseconds: 100));
    
    if (kDebugMode) {
      debugPrint('Flushed ${entries.length} error logs to service');
    }
  }
  
  /// Save logs locally
  Future<void> _saveLocally(List<ErrorLogEntry> entries) async {
    // TODO: Implement local storage
    // Could use SharedPreferences, SQLite, or file system
    await Future.delayed(Duration(milliseconds: 50));
  }
  
  /// Get recent errors
  List<ErrorLogEntry> getRecentErrors({int limit = 10}) {
    return _errorQueue.toList().take(limit).toList();
  }
  
  /// Get error statistics
  Map<String, dynamic> getStatistics() {
    final errors = _errorQueue.toList();
    
    final severityCounts = <ErrorSeverity, int>{};
    final typeCounts = <String, int>{};
    
    for (final error in errors) {
      // Count by severity
      severityCounts[error.exception.severity] = 
        (severityCounts[error.exception.severity] ?? 0) + 1;
      
      // Count by type
      final type = error.exception.runtimeType.toString();
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    
    return {
      'total_errors': errors.length,
      'by_severity': severityCounts.map((k, v) => MapEntry(k.name, v)),
      'by_type': typeCounts,
      'oldest': errors.isNotEmpty ? errors.first.timestamp.toIso8601String() : null,
      'newest': errors.isNotEmpty ? errors.last.timestamp.toIso8601String() : null,
    };
  }
  
  /// Clear all logs
  void clear() {
    _errorQueue.clear();
  }
  
  /// Dispose resources
  void dispose() {
    _flushTimer?.cancel();
    flush(); // Final flush
  }
}