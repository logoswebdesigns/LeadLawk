// Observability manager to coordinate monitoring.
// Pattern: Facade Pattern - unified monitoring interface.
// Single Responsibility: Coordinate all observability systems.

import 'structured_logger.dart';
import 'log_sinks.dart';
import 'distributed_tracing.dart';
import 'metrics_collector.dart';
import 'health_check.dart';
import 'health_checks.dart';
import 'alerting.dart';

/// Observability manager
class ObservabilityManager {
  static final ObservabilityManager _instance = ObservabilityManager._internal();
  factory ObservabilityManager() => _instance;
  ObservabilityManager._internal();
  
  final StructuredLogger logger = StructuredLogger();
  final DistributedTracer tracer = DistributedTracer();
  final MetricsCollector metrics = MetricsCollector();
  final HealthMonitor health = HealthMonitor();
  final AlertManager alerts = AlertManager();
  
  /// Initialize observability
  Future<void> initialize({
    required String apiUrl,
    bool enableConsoleLogging = true,
    bool enableFileLogging = false,
    String? logFilePath,
  }) async {
    // Configure logging
    if (enableConsoleLogging) {
      logger.addSink(ConsoleLogSink(prettyPrint: true));
    }
    
    if (enableFileLogging && logFilePath != null) {
      logger.addSink(FileLogSink(filePath: logFilePath));
    }
    
    // Initialize metrics
    metrics.initialize(reportInterval: Duration(minutes: 1));
    
    // Register health checks
    health.registerCheck(ApiHealthCheck(apiUrl: apiUrl));
    health.registerCheck(MemoryHealthCheck());
    health.startPeriodicChecks(interval: Duration(seconds: 30));
    
    // Set up alerting
    alerts.addChannel(ConsoleAlertChannel());
    
    // Register alert rules
    _registerAlertRules();
    
    logger.info('Observability initialized', fields: {
      'api_url': apiUrl,
      'console_logging': enableConsoleLogging,
      'file_logging': enableFileLogging,
    });
  }
  
  /// Register default alert rules
  void _registerAlertRules() {
    // API response time alert
    alerts.registerRule(ThresholdAlertRule(
      name: 'api_response_time',
      getValue: () async => 150.0, // Placeholder
      threshold: 500.0,
      severity: AlertSeverity.warning,
      message: 'API response time exceeds 500ms',
      evaluationInterval: Duration(minutes: 1),
    ));
    
    // Memory usage alert
    alerts.registerRule(ThresholdAlertRule(
      name: 'memory_usage',
      getValue: () async => 200.0, // Placeholder
      threshold: 750.0,
      severity: AlertSeverity.critical,
      message: 'Memory usage exceeds 750MB',
      evaluationInterval: Duration(seconds: 30),
    ));
  }
  
  /// Start a traced operation
  Future<T> traceOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Map<String, dynamic>? tags,
  }) async {
    final spanId = tracer.startTrace(operationName, tags: tags);
    
    try {
      final result = await metrics.timeOperation(
        operationName,
        operation,
        tags: tags?.map((k, v) => MapEntry(k, v.toString())),
      );
      
      tracer.endSpan(spanId, status: TraceStatus.success);
      return result;
    } catch (e) {
      tracer.endSpan(spanId, status: TraceStatus.error);
      rethrow;
    }
  }
  
  /// Get system status
  Future<Map<String, dynamic>> getSystemStatus() async {
    final healthStatus = await health.runHealthChecks();
    
    return {
      'health': healthStatus,
      'metrics': {
        // Metrics summary
        'initialized': true,
      },
      'alerts': {
        // Alerts summary
        'initialized': true,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// Shutdown observability
  void shutdown() {
    health.stopPeriodicChecks();
    alerts.stopAllRules();
    
    logger.info('Observability shutdown');
  }
}