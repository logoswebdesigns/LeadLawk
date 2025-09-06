// Health check system for monitoring service health.
// Pattern: Health Check Pattern.
// Single Responsibility: Monitor system health.

import 'dart:async';
import 'structured_logger.dart';

/// Health status
enum HealthStatus {
  healthy,
  degraded,
  unhealthy,
}

/// Health check result
class HealthCheckResult {
  final String name;
  final HealthStatus status;
  final String? message;
  final Map<String, dynamic> details;
  final Duration? responseTime;
  final DateTime timestamp;
  
  HealthCheckResult({
    required this.name,
    required this.status,
    this.message,
    Map<String, dynamic>? details,
    this.responseTime,
    required this.timestamp,
  }) : details = details ?? {};
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status.name,
    'message': message,
    'details': details,
    'response_time_ms': responseTime?.inMilliseconds,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Health check interface
abstract class HealthCheck {
  String get name;
  Future<HealthCheckResult> check();
}

/// Health monitor
class HealthMonitor {
  static final HealthMonitor _instance = HealthMonitor._internal();
  factory HealthMonitor() => _instance;
  HealthMonitor._internal();
  
  final List<HealthCheck> _checks = [];
  final StructuredLogger _logger = StructuredLogger();
  Timer? _periodicCheckTimer;
  HealthStatus _overallStatus = HealthStatus.healthy;
  
  /// Register a health check
  void registerCheck(HealthCheck check) {
    _checks.add(check);
  }
  
  /// Start periodic health checks
  void startPeriodicChecks({Duration interval = const Duration(seconds: 30)}) {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(interval, (_) => runHealthChecks());
  }
  
  /// Run all health checks
  Future<Map<String, dynamic>> runHealthChecks() async {
    final results = <HealthCheckResult>[];
    var overallStatus = HealthStatus.healthy;
    
    for (final check in _checks) {
      try {
        final stopwatch = Stopwatch()..start();
        final result = await check.check().timeout(
          Duration(seconds: 5),
          onTimeout: () => HealthCheckResult(
            name: check.name,
            status: HealthStatus.unhealthy,
            message: 'Health check timed out',
            timestamp: DateTime.now(),
          ),
        );
        stopwatch.stop();
        
        results.add(result);
        
        // Update overall status
        if (result.status == HealthStatus.unhealthy) {
          overallStatus = HealthStatus.unhealthy;
        } else if (result.status == HealthStatus.degraded && 
                   overallStatus != HealthStatus.unhealthy) {
          overallStatus = HealthStatus.degraded;
        }
        
        _logger.debug('Health check completed', fields: result.toJson());
      } catch (e) {
        final result = HealthCheckResult(
          name: check.name,
          status: HealthStatus.unhealthy,
          message: 'Health check failed: $e',
          timestamp: DateTime.now(),
        );
        results.add(result);
        overallStatus = HealthStatus.unhealthy;
        
        _logger.error('Health check failed', fields: result.toJson());
      }
    }
    
    _overallStatus = overallStatus;
    
    return {
      'status': overallStatus.name,
      'timestamp': DateTime.now().toIso8601String(),
      'checks': results.map((r) => r.toJson()).toList(),
    };
  }
  
  /// Get current health status
  HealthStatus get status => _overallStatus;
  
  /// Stop periodic checks
  void stopPeriodicChecks() {
    _periodicCheckTimer?.cancel();
  }
}