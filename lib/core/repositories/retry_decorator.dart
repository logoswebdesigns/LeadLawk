import 'dart:math';
import 'package:dartz/dartz.dart';
import '../error/failures.dart';
import 'base_repository.dart';

/// Decorator that adds retry logic with exponential backoff
class RetryDecorator<T> implements BaseRepository<T> {
  final BaseRepository<T> _repository;
  final int _maxRetries;
  final Duration _initialDelay;
  final double _backoffMultiplier;
  final Duration _maxDelay;

  RetryDecorator({
    required BaseRepository<T> repository,
    int maxRetries = 5,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    Duration maxDelay = const Duration(seconds: 30),
  })  : _repository = repository,
        _maxRetries = maxRetries,
        _initialDelay = initialDelay,
        _backoffMultiplier = backoffMultiplier,
        _maxDelay = maxDelay;

  @override
  Future<Either<Failure, List<T>>> getAll({Map<String, dynamic>? filters}) =>
      _retryOperation(() => _repository.getAll(filters: filters));

  @override
  Future<Either<Failure, T>> getById(String id) =>
      _retryOperation(() => _repository.getById(id));

  @override
  Future<Either<Failure, T>> create(T entity) =>
      _retryOperation(() => _repository.create(entity));

  @override
  Future<Either<Failure, T>> update(T entity) =>
      _retryOperation(() => _repository.update(entity));

  @override
  Future<Either<Failure, void>> delete(String id) =>
      _retryOperation(() => _repository.delete(id));

  @override
  Future<Either<Failure, void>> deleteMany(List<String> ids) =>
      _retryOperation(() => _repository.deleteMany(ids));

  @override
  Future<Either<Failure, bool>> exists(String id) =>
      _retryOperation(() => _repository.exists(id));

  @override
  Future<Either<Failure, int>> count({Map<String, dynamic>? filters}) =>
      _retryOperation(() => _repository.count(filters: filters));

  @override
  Future<Either<Failure, void>> clearCache() =>
      _retryOperation(() => _repository.clearCache());

  @override
  Future<Either<Failure, void>> refresh() =>
      _retryOperation(() => _repository.refresh());

  /// Execute operation with retry logic
  Future<Either<Failure, R>> _retryOperation<R>(
    Future<Either<Failure, R>> Function() operation,
  ) async {
    var attempts = 0;
    var delay = _initialDelay;

    while (attempts <= _maxRetries) {
      try {
        final result = await operation();
        
        // Return success immediately
        if (result.isRight()) {
          return result;
        }

        // Check if we should retry this failure
        final failure = result.fold((l) => l, (r) => null)!;
        if (!_shouldRetry(failure) || attempts == _maxRetries) {
          return result;
        }

        attempts++;
        
        // Wait before retry with exponential backoff + jitter
        if (attempts <= _maxRetries) {
          final jitter = Random().nextDouble() * 0.1; // 0-10% jitter
          final actualDelay = Duration(
            milliseconds: (delay.inMilliseconds * (1 + jitter)).round(),
          );
          
          await Future.delayed(actualDelay);
          
          // Calculate next delay with exponential backoff
          delay = Duration(
            milliseconds: min(
              (delay.inMilliseconds * _backoffMultiplier).round(),
              _maxDelay.inMilliseconds,
            ),
          );
        }
      } catch (e) {
        // Convert exceptions to failures
        if (attempts == _maxRetries) {
          return Left(NetworkFailure('Max retries exceeded: $e'));
        }
        
        attempts++;
        await Future.delayed(delay);
        delay = Duration(
          milliseconds: min(
            (delay.inMilliseconds * _backoffMultiplier).round(),
            _maxDelay.inMilliseconds,
          ),
        );
      }
    }

    return const Left(NetworkFailure('Max retries exceeded'));
  }

  /// Determine if a failure should trigger a retry
  bool _shouldRetry(Failure failure) {
    switch (failure.runtimeType) {
      case NetworkFailure _:
      case ServerFailure _:
        return _isRetryableServerError(failure.message);
      case CacheFailure _:
        return true; // Always retry cache failures
      case ValidationFailure _:
        return false; // Never retry validation errors
      case ProcessingFailure _:
        return false; // Never retry processing errors
      default:
        return false;
    }
  }

  /// Check if server error message indicates a retryable condition
  bool _isRetryableServerError(String message) {
    final retryablePatterns = [
      'timeout',
      'connection',
      'network',
      '5', // 5xx server errors
      'internal server error',
      'bad gateway',
      'service unavailable',
      'gateway timeout',
    ];

    final lowerMessage = message.toLowerCase();
    return retryablePatterns.any((pattern) => lowerMessage.contains(pattern));
  }
}