import 'dart:async';
import 'package:dartz/dartz.dart';
import '../error/failures.dart';
import 'base_repository.dart';

/// Circuit breaker states
enum CircuitState { closed, open, halfOpen }

/// Circuit breaker for fault tolerance
class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration timeout;
  
  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  DateTime? _nextAttempt;

  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.timeout = const Duration(seconds: 30),
  });

  CircuitState get state => _state;
  int get failureCount => _failureCount;

  /// Execute operation through circuit breaker
  Future<Either<Failure, T>> execute<T>(
    Future<Either<Failure, T>> Function() operation,
  ) async {
    if (_state == CircuitState.open) {
      if (_shouldAttemptReset()) {
        _state = CircuitState.halfOpen;
      } else {
        return Left(NetworkFailure('Circuit breaker is OPEN for $name'));
      }
    }

    try {
      final result = await operation();
      
      if (result.isRight()) {
        _onSuccess();
      } else {
        _onFailure();
      }
      
      return result;
    } catch (e) {
      _onFailure();
      return Left(NetworkFailure('Circuit breaker caught exception: $e'));
    }
  }

  /// Handle successful operation
  void _onSuccess() {
    _failureCount = 0;
    _state = CircuitState.closed;
    _lastFailureTime = null;
    _nextAttempt = null;
  }

  /// Handle failed operation
  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_state == CircuitState.halfOpen) {
      _state = CircuitState.open;
      _nextAttempt = DateTime.now().add(timeout);
    } else if (_failureCount >= failureThreshold) {
      _state = CircuitState.open;
      _nextAttempt = DateTime.now().add(timeout);
    }
  }

  /// Check if we should attempt to reset the circuit breaker
  bool _shouldAttemptReset() {
    return _nextAttempt != null && DateTime.now().isAfter(_nextAttempt!);
  }

  /// Reset circuit breaker manually
  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
    _nextAttempt = null;
  }

  /// Get circuit breaker status
  Map<String, dynamic> getStatus() {
    return {
      'name': name,
      'state': _state.toString(),
      'failure_count': _failureCount,
      'failure_threshold': failureThreshold,
      'last_failure': _lastFailureTime?.toIso8601String(),
      'next_attempt': _nextAttempt?.toIso8601String(),
    };
  }
}

/// Decorator that adds circuit breaker functionality
class CircuitBreakerDecorator<T> implements BaseRepository<T> {
  final BaseRepository<T> _repository;
  final CircuitBreaker _circuitBreaker;

  CircuitBreakerDecorator({
    required BaseRepository<T> repository,
    required String serviceName,
    int failureThreshold = 5,
    Duration timeout = const Duration(seconds: 30),
  })  : _repository = repository,
        _circuitBreaker = CircuitBreaker(
          name: serviceName,
          failureThreshold: failureThreshold,
          timeout: timeout,
        );

  CircuitBreaker get circuitBreaker => _circuitBreaker;

  @override
  Future<Either<Failure, List<T>>> getAll({Map<String, dynamic>? filters}) =>
      _circuitBreaker.execute(() => _repository.getAll(filters: filters));

  @override
  Future<Either<Failure, T>> getById(String id) =>
      _circuitBreaker.execute(() => _repository.getById(id));

  @override
  Future<Either<Failure, T>> create(T entity) =>
      _circuitBreaker.execute(() => _repository.create(entity));

  @override
  Future<Either<Failure, T>> update(T entity) =>
      _circuitBreaker.execute(() => _repository.update(entity));

  @override
  Future<Either<Failure, void>> delete(String id) =>
      _circuitBreaker.execute(() => _repository.delete(id));

  @override
  Future<Either<Failure, void>> deleteMany(List<String> ids) =>
      _circuitBreaker.execute(() => _repository.deleteMany(ids));

  @override
  Future<Either<Failure, bool>> exists(String id) =>
      _circuitBreaker.execute(() => _repository.exists(id));

  @override
  Future<Either<Failure, int>> count({Map<String, dynamic>? filters}) =>
      _circuitBreaker.execute(() => _repository.count(filters: filters));

  @override
  Future<Either<Failure, void>> clearCache() =>
      _circuitBreaker.execute(() => _repository.clearCache());

  @override
  Future<Either<Failure, void>> refresh() =>
      _circuitBreaker.execute(() => _repository.refresh());
}