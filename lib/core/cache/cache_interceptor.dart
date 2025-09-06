// HTTP cache interceptor for Dio.
// Pattern: Interceptor Pattern - caches HTTP responses.
// Single Responsibility: HTTP response caching.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'cache_manager.dart';
import 'cache_policy.dart';

/// HTTP cache interceptor for automatic API response caching
class CacheInterceptor extends Interceptor {
  final CacheManager _cacheManager;
  final CachePolicy _policy;
  
  CacheInterceptor({
    CacheManager? cacheManager,
    CachePolicy? policy,
  }) : _cacheManager = cacheManager ?? CacheManager(),
       _policy = policy ?? CachePolicy();
  
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Check if request should be cached
    if (!_policy.shouldCache(options)) {
      return handler.next(options);
    }
    
    // Check for cache hit
    final cacheKey = _getCacheKey(options);
    final cachedResponse = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
    
    if (cachedResponse != null) {
      // Return cached response
      final response = Response(
        requestOptions: options,
        data: cachedResponse['data'],
        statusCode: cachedResponse['statusCode'] ?? 200,
        headers: Headers.fromMap(cachedResponse['headers'] ?? {}),
      );
      
      if (kDebugMode) {
        debugPrint('Cache hit for: ${options.uri}');
      }
      
      return handler.resolve(response);
    }
    
    // Add cache headers if available
    final etag = await _cacheManager.get<String>('${cacheKey}_etag');
    if (etag != null) {
      options.headers['If-None-Match'] = etag;
    }
    
    handler.next(options);
  }
  
  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    // Check if response should be cached
    if (!_policy.shouldCacheResponse(response)) {
      return handler.next(response);
    }
    
    final cacheKey = _getCacheKey(response.requestOptions);
    
    // Handle 304 Not Modified
    if (response.statusCode == 304) {
      final cachedResponse = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cachedResponse != null) {
        response.data = cachedResponse['data'];
        response.statusCode = 200;
      }
      return handler.next(response);
    }
    
    // Cache successful responses
    if (response.statusCode == 200) {
      final ttl = _policy.getTtl(response.requestOptions);
      
      await _cacheManager.set(
        cacheKey,
        {
          'data': response.data,
          'statusCode': response.statusCode,
          'headers': response.headers.map,
        },
        ttl: ttl,
        persistent: _policy.isPersistent(response.requestOptions),
      );
      
      // Store ETag if present
      final etag = response.headers.value('ETag');
      if (etag != null) {
        await _cacheManager.set(
          '${cacheKey}_etag',
          etag,
          ttl: ttl,
        );
      }
      
      if (kDebugMode) {
        debugPrint('Cached response for: ${response.requestOptions.uri}');
      }
    }
    
    handler.next(response);
  }
  
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Return cached response on network error if available
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout) {
      
      final cacheKey = _getCacheKey(err.requestOptions);
      final cachedResponse = await _cacheManager.get<Map<String, dynamic>>(
        cacheKey,
        checkExpiry: false, // Return stale cache on error
      );
      
      if (cachedResponse != null) {
        final response = Response(
          requestOptions: err.requestOptions,
          data: cachedResponse['data'],
          statusCode: cachedResponse['statusCode'] ?? 200,
          headers: Headers.fromMap(cachedResponse['headers'] ?? {}),
        );
        
        if (kDebugMode) {
          debugPrint('Returning stale cache due to network error');
        }
        
        return handler.resolve(response);
      }
    }
    
    handler.next(err);
  }
  
  String _getCacheKey(RequestOptions options) {
    final queryParams = options.queryParameters.entries
      .map((e) => '${e.key}=${e.value}')
      .join('&');
    
    return '${options.method}_${options.path}${queryParams.isNotEmpty ? '?$queryParams' : ''}';
  }
  
  /// Clear cache for specific endpoint
  Future<void> clearEndpointCache(String endpoint) async {
    await _cacheManager.invalidatePattern(endpoint);
  }
  
  /// Clear all HTTP cache
  Future<void> clearAllCache() async {
    await _cacheManager.clear();
  }
}