import 'package:dartz/dartz.dart';
import '../error/failures.dart';
import 'base_repository.dart';
import 'cache_manager.dart';

/// Decorator that adds caching functionality to repositories
class CacheDecorator<T> implements BaseRepository<T> {
  final BaseRepository<T> _repository;
  final String _cachePrefix;
  final Duration _defaultTtl;
  final CacheManager _cacheManager;

  CacheDecorator({
    required BaseRepository<T> repository,
    required String cachePrefix,
    Duration? defaultTtl,
    CacheManager? cacheManager,
  })  : _repository = repository,
        _cachePrefix = cachePrefix,
        _defaultTtl = defaultTtl ?? Duration(minutes: 5),
        _cacheManager = cacheManager ?? CacheManager.instance;

  @override
  Future<Either<Failure, List<T>>> getAll({Map<String, dynamic>? filters}) async {
    final cacheKey = _buildCacheKey('all', filters);
    
    // Try cache first
    final cached = _cacheManager.get<List<T>>(cacheKey);
    if (cached != null) {
      return Right(cached);
    }

    // Fetch from repository
    final result = await _repository.getAll(filters: filters);
    
    // Cache successful results
    result.fold(
      (failure) => null,
      (data) => _cacheManager.set(cacheKey, data, _defaultTtl),
    );

    return result;
  }

  @override
  Future<Either<Failure, T>> getById(String id) async {
    final cacheKey = _buildCacheKey('item', {'id': id});
    
    // Try cache first
    final cached = _cacheManager.get<T>(cacheKey);
    if (cached != null) {
      return Right(cached);
    }

    // Fetch from repository
    final result = await _repository.getById(id);
    
    // Cache successful results
    result.fold(
      (failure) => null,
      (data) => _cacheManager.set(cacheKey, data, _defaultTtl),
    );

    return result;
  }

  @override
  Future<Either<Failure, T>> create(T entity) async {
    final result = await _repository.create(entity);
    
    // Invalidate related caches on successful creation
    result.fold(
      (failure) => null,
      (data) => _invalidateListCaches(),
    );

    return result;
  }

  @override
  Future<Either<Failure, T>> update(T entity) async {
    final result = await _repository.update(entity);
    
    // Invalidate related caches on successful update
    result.fold(
      (failure) => null,
      (data) => _invalidateEntityCaches(entity),
    );

    return result;
  }

  @override
  Future<Either<Failure, void>> delete(String id) async {
    final result = await _repository.delete(id);
    
    // Invalidate related caches on successful deletion
    result.fold(
      (failure) => null,
      (_) => _invalidateEntityCachesById(id),
    );

    return result;
  }

  @override
  Future<Either<Failure, void>> deleteMany(List<String> ids) async {
    final result = await _repository.deleteMany(ids);
    
    // Invalidate related caches on successful deletion
    result.fold(
      (failure) => null,
      (_) {
        for (final id in ids) {
          _invalidateEntityCachesById(id);
        }
      },
    );

    return result;
  }

  @override
  Future<Either<Failure, bool>> exists(String id) async {
    // Don't cache existence checks as they're typically quick
    return _repository.exists(id);
  }

  @override
  Future<Either<Failure, int>> count({Map<String, dynamic>? filters}) async {
    final cacheKey = _buildCacheKey('count', filters);
    
    // Try cache first
    final cached = _cacheManager.get<int>(cacheKey);
    if (cached != null) {
      return Right(cached);
    }

    // Fetch from repository
    final result = await _repository.count(filters: filters);
    
    // Cache successful results with shorter TTL
    result.fold(
      (failure) => null,
      (data) => _cacheManager.set(cacheKey, data, Duration(minutes: 1)),
    );

    return result;
  }

  @override
  Future<Either<Failure, void>> clearCache() async {
    await _cacheManager.removeByPrefix(_cachePrefix);
    return _repository.clearCache();
  }

  @override
  Future<Either<Failure, void>> refresh() async {
    await _cacheManager.removeByPrefix(_cachePrefix);
    return _repository.refresh();
  }

  /// Build cache key from operation and parameters
  String _buildCacheKey(String operation, Map<String, dynamic>? params) {
    final parts = [_cachePrefix, operation];
    
    if (params != null && params.isNotEmpty) {
      final sortedKeys = params.keys.toList()..sort();
      final paramString = sortedKeys
          .map((key) => '$key:${params[key]}')
          .join(',');
      parts.add(paramString);
    }
    
    return parts.join('_');
  }

  /// Invalidate all list-related caches
  Future<void> _invalidateListCaches() async {
    await _cacheManager.removeByPrefix('${_cachePrefix}_all');
    await _cacheManager.removeByPrefix('${_cachePrefix}_count');
  }

  /// Invalidate caches for specific entity
  Future<void> _invalidateEntityCaches(T entity) async {
    // This is generic - specific implementations might need to override
    await _invalidateListCaches();
  }

  /// Invalidate caches for entity by ID
  Future<void> _invalidateEntityCachesById(String id) async {
    await _cacheManager.remove(_buildCacheKey('item', {'id': id}));
    await _invalidateListCaches();
  }
}