// Retry decorator for repository pattern.
// Pattern: Decorator Pattern with Retry Pattern.
// Single Responsibility: Add retry logic to repositories.

import 'dart:async';
import '../errors/error_recovery.dart';
import '../monitoring/structured_logger.dart';

/// Retry decorator
class RetryDecorator<T> {
  final T _repository;
  final ErrorRecovery _errorRecovery;
  final StructuredLogger _logger;
  final RetryPolicy defaultPolicy;
  
  RetryDecorator({
    required T repository,
    ErrorRecovery? errorRecovery,
    StructuredLogger? logger,
    RetryPolicy? defaultPolicy,
  }) : _repository = repository,
       _errorRecovery = errorRecovery ?? ErrorRecovery(),
       _logger = logger ?? StructuredLogger(),
       defaultPolicy = defaultPolicy ?? RetryPolicy.defaultPolicy;
  
  T get repository => _repository;
  
  /// Execute with retry
  Future<R> executeWithRetry<R>({
    required Future<R> Function() operation,
    required String operationName,
    RetryPolicy? policy,
    String? circuitBreakerName,
  }) async {
    policy ??= defaultPolicy;
    
    _logger.debug('Starting operation with retry', fields: {
      'operation': operationName,
      'max_attempts': policy.maxAttempts,
      'circuit_breaker': circuitBreakerName,
    });
    
    return await _errorRecovery.executeWithRetry(
      operation,
      policy: policy,
      circuitBreakerName: circuitBreakerName,
      onRetry: (attempt, delay) {
        _logger.warning('Retrying operation', fields: {
          'operation': operationName,
          'attempt': attempt,
          'delay_ms': delay.inMilliseconds,
        });
      },
      onError: (error, attempt) {
        _logger.error('Operation attempt failed', fields: {
          'operation': operationName,
          'attempt': attempt,
          'error': error.toString(),
        });
      },
    );
  }
  
  /// Execute with timeout
  Future<R> executeWithTimeout<R>({
    required Future<R> Function() operation,
    required String operationName,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _logger.debug('Starting operation with timeout', fields: {
      'operation': operationName,
      'timeout_ms': timeout.inMilliseconds,
    });
    
    return await _errorRecovery.executeWithTimeout(
      operation,
      timeout,
      onTimeout: () {
        _logger.error('Operation timed out', fields: {
          'operation': operationName,
          'timeout_ms': timeout.inMilliseconds,
        });
        throw TimeoutException('$operationName timed out after ${timeout.inSeconds}s');
      },
    );
  }
  
  /// Execute with fallback
  Future<R> executeWithFallback<R>({
    required Future<R> Function() primary,
    required Future<R> Function() fallback,
    required String operationName,
  }) async {
    _logger.debug('Starting operation with fallback', fields: {
      'operation': operationName,
    });
    
    return await _errorRecovery.executeWithFallback(
      primary,
      fallback,
      shouldFallback: (error) {
        _logger.warning('Primary operation failed, using fallback', fields: {
          'operation': operationName,
          'error': error.toString(),
        });
        return true;
      },
    );
  }
}