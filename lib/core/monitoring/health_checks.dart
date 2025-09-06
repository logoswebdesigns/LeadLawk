// Health check implementations.
// Pattern: Health Check Pattern implementations.
// Single Responsibility: Check specific system components.

import 'dart:async';
import 'package:dio/dio.dart';
import 'health_check.dart';

/// API health check
class ApiHealthCheck implements HealthCheck {
  final String apiUrl;
  final Dio dio;
  
  ApiHealthCheck({required this.apiUrl, Dio? dio}) 
    : dio = dio ?? Dio();
  
  @override
  String get name => 'API';
  
  @override
  Future<HealthCheckResult> check() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final response = await dio.get('$apiUrl/health');
      stopwatch.stop();
      
      if (response.statusCode == 200) {
        return HealthCheckResult(
          name: name,
          status: HealthStatus.healthy,
          message: 'API is responsive',
          responseTime: stopwatch.elapsed,
          timestamp: DateTime.now(),
          details: {
            'endpoint': '$apiUrl/health',
            'status_code': response.statusCode,
          },
        );
      } else {
        return HealthCheckResult(
          name: name,
          status: HealthStatus.degraded,
          message: 'API returned ${response.statusCode}',
          responseTime: stopwatch.elapsed,
          timestamp: DateTime.now(),
          details: {
            'endpoint': '$apiUrl/health',
            'status_code': response.statusCode,
          },
        );
      }
    } catch (e) {
      stopwatch.stop();
      return HealthCheckResult(
        name: name,
        status: HealthStatus.unhealthy,
        message: 'API is unreachable: $e',
        responseTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
        details: {
          'endpoint': '$apiUrl/health',
          'error': e.toString(),
        },
      );
    }
  }
}

/// Database health check
class DatabaseHealthCheck implements HealthCheck {
  final Future<bool> Function() checkConnection;
  
  DatabaseHealthCheck({required this.checkConnection});
  
  @override
  String get name => 'Database';
  
  @override
  Future<HealthCheckResult> check() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final isConnected = await checkConnection();
      stopwatch.stop();
      
      return HealthCheckResult(
        name: name,
        status: isConnected ? HealthStatus.healthy : HealthStatus.unhealthy,
        message: isConnected ? 'Database is connected' : 'Database connection failed',
        responseTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      stopwatch.stop();
      return HealthCheckResult(
        name: name,
        status: HealthStatus.unhealthy,
        message: 'Database check failed: $e',
        responseTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
      );
    }
  }
}

/// Memory health check
class MemoryHealthCheck implements HealthCheck {
  final int warningThresholdMB;
  final int criticalThresholdMB;
  
  MemoryHealthCheck({
    this.warningThresholdMB = 500,
    this.criticalThresholdMB = 750,
  });
  
  @override
  String get name => 'Memory';
  
  @override
  Future<HealthCheckResult> check() async {
    // Simplified memory check
    // In production, use actual memory metrics
    final usedMemoryMB = 200; // Placeholder
    
    HealthStatus status;
    String message;
    
    if (usedMemoryMB > criticalThresholdMB) {
      status = HealthStatus.unhealthy;
      message = 'Memory usage critical';
    } else if (usedMemoryMB > warningThresholdMB) {
      status = HealthStatus.degraded;
      message = 'Memory usage high';
    } else {
      status = HealthStatus.healthy;
      message = 'Memory usage normal';
    }
    
    return HealthCheckResult(
      name: name,
      status: status,
      message: message,
      timestamp: DateTime.now(),
      details: {
        'used_mb': usedMemoryMB,
        'warning_threshold_mb': warningThresholdMB,
        'critical_threshold_mb': criticalThresholdMB,
      },
    );
  }
}