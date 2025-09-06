import 'package:dartz/dartz.dart';
import '../error/failures.dart';

/// Base repository interface providing common functionality
abstract class BaseRepository<T> {
  /// Get all entities with optional filtering
  Future<Either<Failure, List<T>>> getAll({Map<String, dynamic>? filters});
  
  /// Get entity by ID
  Future<Either<Failure, T>> getById(String id);
  
  /// Create new entity
  Future<Either<Failure, T>> create(T entity);
  
  /// Update existing entity
  Future<Either<Failure, T>> update(T entity);
  
  /// Delete entity by ID
  Future<Either<Failure, void>> delete(String id);
  
  /// Delete multiple entities by IDs
  Future<Either<Failure, void>> deleteMany(List<String> ids);
  
  /// Check if entity exists
  Future<Either<Failure, bool>> exists(String id);
  
  /// Get count of entities with optional filtering
  Future<Either<Failure, int>> count({Map<String, dynamic>? filters});
  
  /// Clear all cached data for this repository
  Future<Either<Failure, void>> clearCache();
  
  /// Refresh data from remote source
  Future<Either<Failure, void>> refresh();
}

/// Configuration for repository behavior
class RepositoryConfig {
  final Duration cacheTimeout;
  final int maxRetries;
  final Duration initialRetryDelay;
  final int circuitBreakerThreshold;
  final Duration circuitBreakerResetTimeout;
  final bool enablePersistentCache;
  final bool enableNetworkCache;

  const RepositoryConfig({
    this.cacheTimeout = const Duration(minutes: 5),
    this.maxRetries = 5,
    this.initialRetryDelay = const Duration(seconds: 1),
    this.circuitBreakerThreshold = 5,
    this.circuitBreakerResetTimeout = const Duration(seconds: 30),
    this.enablePersistentCache = true,
    this.enableNetworkCache = true,
  });
}