// Cache policy for determining what and how to cache.
// Pattern: Strategy Pattern - configurable caching strategies.
// Single Responsibility: Cache policy decisions.

import 'package:dio/dio.dart';

/// Cache policy for determining caching behavior
class CachePolicy {
  final Map<String, Duration> _endpointTtls;
  final Set<String> _cachedEndpoints;
  final Set<String> _persistentEndpoints;
  final Duration _defaultTtl;
  
  CachePolicy({
    Map<String, Duration>? endpointTtls,
    Set<String>? cachedEndpoints,
    Set<String>? persistentEndpoints,
    Duration? defaultTtl,
  }) : _endpointTtls = endpointTtls ?? _defaultEndpointTtls(),
       _cachedEndpoints = cachedEndpoints ?? _defaultCachedEndpoints(),
       _persistentEndpoints = persistentEndpoints ?? _defaultPersistentEndpoints(),
       _defaultTtl = defaultTtl ?? Duration(minutes: 5);
  
  /// Check if request should be cached
  bool shouldCache(RequestOptions options) {
    // Only cache GET requests by default
    if (options.method != 'GET') {
      return false;
    }
    
    // Check if endpoint is in cached list
    return _cachedEndpoints.any((pattern) => 
      options.path.contains(pattern)
    );
  }
  
  /// Check if response should be cached
  bool shouldCacheResponse(Response response) {
    // Only cache successful responses
    if (response.statusCode != 200 && response.statusCode != 304) {
      return false;
    }
    
    // Check cache control headers
    final cacheControl = response.headers.value('Cache-Control');
    if (cacheControl != null) {
      if (cacheControl.contains('no-cache') || 
          cacheControl.contains('no-store')) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Get TTL for endpoint
  Duration getTtl(RequestOptions options) {
    // Check specific endpoint TTLs
    for (final entry in _endpointTtls.entries) {
      if (options.path.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Check cache control headers
    final cacheControl = options.headers['Cache-Control'];
    if (cacheControl != null && cacheControl is String) {
      final maxAge = _parseMaxAge(cacheControl);
      if (maxAge != null) {
        return Duration(seconds: maxAge);
      }
    }
    
    return _defaultTtl;
  }
  
  /// Check if endpoint should be persisted
  bool isPersistent(RequestOptions options) {
    return _persistentEndpoints.any((pattern) => 
      options.path.contains(pattern)
    );
  }
  
  int? _parseMaxAge(String cacheControl) {
    final regex = RegExp(r'max-age=(\d+)');
    final match = regex.firstMatch(cacheControl);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }
  
  static Map<String, Duration> _defaultEndpointTtls() => {
    '/leads': Duration(minutes: 2),
    '/jobs': Duration(seconds: 30),
    '/analytics': Duration(minutes: 10),
    '/settings': const Duration(hours: 1),
    '/templates': Duration(minutes: 30),
  };
  
  static Set<String> _defaultCachedEndpoints() => {
    '/leads',
    '/jobs',
    '/analytics',
    '/settings',
    '/templates',
    '/pitches',
    '/goals',
  };
  
  static Set<String> _defaultPersistentEndpoints() => {
    '/settings',
    '/templates',
    '/pitches',
  };
}

/// Offline cache policy for aggressive caching
class OfflineCachePolicy extends CachePolicy {
  OfflineCachePolicy() : super(
    defaultTtl: const Duration(hours: 24),
    persistentEndpoints: {
      '/leads',
      '/settings',
      '/templates',
      '/pitches',
    },
  );
  
  @override
  bool shouldCache(RequestOptions options) {
    // Cache all GET and HEAD requests
    return options.method == 'GET' || options.method == 'HEAD';
  }
  
  @override
  Duration getTtl(RequestOptions options) {
    // Use longer TTLs for offline mode
    return const Duration(hours: 24);
  }
}

/// Development cache policy with short TTLs
class DevelopmentCachePolicy extends CachePolicy {
  DevelopmentCachePolicy() : super(
    defaultTtl: Duration(seconds: 10),
    endpointTtls: {
      '/leads': Duration(seconds: 5),
      '/jobs': Duration(seconds: 5),
    },
    persistentEndpoints: {}, // No persistence in development
  );
}