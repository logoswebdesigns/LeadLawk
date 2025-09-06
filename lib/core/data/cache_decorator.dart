// Cache decorator for repository pattern.
// Pattern: Decorator Pattern - add caching to repositories.
// Single Responsibility: Cache repository responses.

import 'dart:async';
import '../cache/cache_manager.dart';
import '../monitoring/structured_logger.dart';

/// Cache decorator base class
abstract class CacheDecorator<T> {
  final T _repository;
  final CacheManager _cache;
  final StructuredLogger _logger;
  final Duration defaultTtl;
  
  CacheDecorator({
    required T repository,
    CacheManager? cache,
    StructuredLogger? logger,
    this.defaultTtl = const Duration(minutes: 5),
  }) : _repository = repository,
       _cache = cache ?? CacheManager(),
       _logger = logger ?? StructuredLogger();
  
  T get repository => _repository;
  
  /// Get cache key
  String getCacheKey(String method, [List<dynamic>? params]) {
    final paramStr = params?.map((p) => p.toString()).join('_') ?? '';
    return '${T.toString()}_${method}_$paramStr';
  }
  
  /// Cache method result
  Future<R> cacheMethod<R>({
    required String method,
    required Future<R> Function() operation,
    List<dynamic>? params,
    Duration? ttl,
    bool forceRefresh = false,
  }) async {
    final key = getCacheKey(method, params);
    
    // Check cache first unless force refresh
    if (!forceRefresh) {
      final cached = await _cache.get<R>(key);
      if (cached != null) {
        _logger.debug('Cache hit', fields: {'key': key, 'method': method});
        return cached;
      }
    }
    
    // Execute operation
    try {
      final result = await operation();
      
      // Cache result
      await _cache.set(key, result, ttl: ttl ?? defaultTtl);
      _logger.debug('Cache set', fields: {'key': key, 'method': method});
      
      return result;
    } catch (e) {
      _logger.error('Operation failed', fields: {
        'key': key,
        'method': method,
        'error': e.toString(),
      });
      
      // Try to return stale cache on error
      final stale = await _cache.get<R>(key);
      if (stale != null) {
        _logger.warning('Returning stale cache', fields: {'key': key});
        return stale;
      }
      
      rethrow;
    }
  }
  
  /// Invalidate cache
  Future<void> invalidateCache({
    String? method,
    List<dynamic>? params,
  }) async {
    if (method != null) {
      final key = getCacheKey(method, params);
      await _cache.remove(key);
      _logger.debug('Cache invalidated', fields: {'key': key});
    } else {
      // Clear all cache for this repository
      await _cache.clear();
      _logger.debug('All cache cleared', fields: {'repository': T.toString()});
    }
  }
}