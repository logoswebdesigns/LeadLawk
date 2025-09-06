// Error recovery mechanisms.
// Pattern: Retry Pattern with Circuit Breaker.
// Single Responsibility: Automatic error recovery.

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'app_exceptions.dart';

/// Retry policy configuration
class RetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool exponentialBackoff;
  final Set<Type> retryableExceptions;
  
  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.exponentialBackoff = true,
    this.retryableExceptions = const {},
  });
  
  /// Default retry policy
  static const RetryPolicy defaultPolicy = RetryPolicy();
  
  /// Aggressive retry policy for critical operations
  static const RetryPolicy aggressive = RetryPolicy(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 60),
    backoffMultiplier: 1.5,
  );
  
  /// Conservative retry policy
  static const RetryPolicy conservative = RetryPolicy(
    maxAttempts: 2,
    initialDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 10),
    exponentialBackoff: false,
  );
}

/// Circuit breaker states
enum CircuitState {
  closed,    // Normal operation
  open,      // Failing, reject requests
  halfOpen,  // Testing if service recovered
}

/// Circuit breaker for preventing cascading failures
class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration timeout;
  final Duration resetTimeout;
  
  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  Timer? _resetTimer;
  
  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.timeout = const Duration(seconds: 60),
    this.resetTimeout = const Duration(seconds: 30),
  });
  
  /// Check if circuit allows request
  bool get isOpen => _state == CircuitState.open;
  bool get isClosed => _state == CircuitState.closed;
  bool get isHalfOpen => _state == CircuitState.halfOpen;
  
  /// Record success
  void recordSuccess() {
    _failureCount = 0;
    if (_state == CircuitState.halfOpen) {
      _state = CircuitState.closed;
      if (kDebugMode) {
        debugPrint('Circuit breaker "$name" closed after successful test');
      }
    }
  }
  
  /// Record failure
  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    
    if (_failureCount >= failureThreshold) {
      _openCircuit();
    }
  }
  
  /// Open the circuit
  void _openCircuit() {
    _state = CircuitState.open;
    if (kDebugMode) {
      debugPrint('Circuit breaker "$name" opened after $_failureCount failures');
    }
    
    // Schedule transition to half-open
    _resetTimer?.cancel();
    _resetTimer = Timer(resetTimeout, () {
      _state = CircuitState.halfOpen;
      if (kDebugMode) {
        debugPrint('Circuit breaker "$name" half-open for testing');
      }
    });
  }
  
  /// Reset the circuit
  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
    _resetTimer?.cancel();
  }
  
  /// Get circuit statistics
  Map<String, dynamic> getStatistics() => {
    'name': name,
    'state': _state.name,
    'failure_count': _failureCount,
    'last_failure': _lastFailureTime?.toIso8601String(),
  };
}

/// Error recovery manager
class ErrorRecovery {
  static final ErrorRecovery _instance = ErrorRecovery._internal();
  factory ErrorRecovery() => _instance;
  ErrorRecovery._internal();
  
  final Map<String, CircuitBreaker> _circuitBreakers = {};
  final Random _random = Random();
  
  /// Get or create circuit breaker
  CircuitBreaker getCircuitBreaker(String name) {
    return _circuitBreakers.putIfAbsent(
      name,
      () => CircuitBreaker(name: name),
    );
  }
  
  /// Execute with retry
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    RetryPolicy? policy,
    String? circuitBreakerName,
    void Function(int attempt, Duration delay)? onRetry,
    void Function(dynamic error, int attempt)? onError,
  }) async {
    policy ??= RetryPolicy.defaultPolicy;
    
    // Check circuit breaker if configured
    if (circuitBreakerName != null) {
      final breaker = getCircuitBreaker(circuitBreakerName);
      if (breaker.isOpen) {
        throw UnknownException(
          message: 'Service unavailable - circuit breaker open',
        );
      }
    }
    
    int attempt = 0;
    Duration delay = policy.initialDelay;
    dynamic lastError;
    
    while (attempt < policy.maxAttempts) {
      attempt++;
      
      try {
        final result = await operation();
        
        // Record success to circuit breaker
        if (circuitBreakerName != null) {
          getCircuitBreaker(circuitBreakerName).recordSuccess();
        }
        
        return result;
      } catch (error) {
        lastError = error;
        
        // Record failure to circuit breaker
        if (circuitBreakerName != null) {
          getCircuitBreaker(circuitBreakerName).recordFailure();
        }
        
        // Call error callback
        onError?.call(error, attempt);
        
        // Check if error is retryable
        if (!_isRetryable(error, policy)) {
          rethrow;
        }
        
        // Check if we've exhausted attempts
        if (attempt >= policy.maxAttempts) {
          break;
        }
        
        // Calculate next delay
        if (policy.exponentialBackoff) {
          delay = _calculateExponentialDelay(
            attempt,
            policy.initialDelay,
            policy.backoffMultiplier,
            policy.maxDelay,
          );
        }
        
        // Add jitter to prevent thundering herd
        delay = _addJitter(delay);
        
        // Call retry callback
        onRetry?.call(attempt, delay);
        
        if (kDebugMode) {
          debugPrint('Retry attempt $attempt after ${delay.inMilliseconds}ms');
        }
        
        // Wait before retry
        await Future.delayed(delay);
      }
    }
    
    // All attempts exhausted
    throw UnknownException(
      message: 'Operation failed after $attempt attempts',
      originalError: lastError,
    );
  }
  
  /// Check if error is retryable
  bool _isRetryable(dynamic error, RetryPolicy policy) {
    // Check custom retryable exceptions
    if (policy.retryableExceptions.isNotEmpty) {
      return policy.retryableExceptions.contains(error.runtimeType);
    }
    
    // Check AppException retryable flag
    if (error is AppException) {
      return error.isRetryable;
    }
    
    // Default to not retryable for unknown errors
    return false;
  }
  
  /// Calculate exponential backoff delay
  Duration _calculateExponentialDelay(
    int attempt,
    Duration initialDelay,
    double multiplier,
    Duration maxDelay,
  ) {
    final exponentialDelay = initialDelay.inMilliseconds * 
      pow(multiplier, attempt - 1);
    
    final clampedDelay = exponentialDelay.clamp(
      initialDelay.inMilliseconds,
      maxDelay.inMilliseconds,
    ).toInt();
    
    return Duration(milliseconds: clampedDelay);
  }
  
  /// Add jitter to delay
  Duration _addJitter(Duration delay) {
    final jitter = _random.nextInt(delay.inMilliseconds ~/ 4);
    return Duration(milliseconds: delay.inMilliseconds + jitter);
  }
  
  /// Execute with fallback
  Future<T> executeWithFallback<T>(
    Future<T> Function() primary,
    Future<T> Function() fallback, {
    bool Function(dynamic error)? shouldFallback,
  }) async {
    try {
      return await primary();
    } catch (error) {
      if (shouldFallback?.call(error) ?? true) {
        if (kDebugMode) {
          debugPrint('Primary operation failed, using fallback: $error');
        }
        return await fallback();
      }
      rethrow;
    }
  }
  
  /// Execute with timeout
  Future<T> executeWithTimeout<T>(
    Future<T> Function() operation,
    Duration timeout, {
    T Function()? onTimeout,
  }) async {
    try {
      return await operation().timeout(
        timeout,
        onTimeout: onTimeout != null
          ? () => Future.value(onTimeout())
          : null,
      );
    } on TimeoutException catch (e) {
      throw TimeoutException(
        message: 'Operation timed out',
        timeout: timeout,
        originalError: e,
      );
    }
  }
  
  /// Get all circuit breaker statistics
  Map<String, dynamic> getCircuitBreakerStats() {
    return Map.fromEntries(
      _circuitBreakers.entries.map(
        (e) => MapEntry(e.key, e.value.getStatistics()),
      ),
    );
  }
  
  /// Reset specific circuit breaker
  void resetCircuitBreaker(String name) {
    _circuitBreakers[name]?.reset();
  }
  
  /// Reset all circuit breakers
  void resetAllCircuitBreakers() {
    _circuitBreakers.values.forEach((breaker) => breaker.reset());
  }
}