// Tests for cache manager.
// Pattern: Unit Testing - cache functionality verification.

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:leadloq/core/cache/cache_manager.dart';
import 'package:leadloq/core/cache/cache_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CacheManager Tests', () {
    late CacheManager cacheManager;
    
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      cacheManager = CacheManager();
    });
    
    tearDown(() {
      cacheManager.clear();
    });
    
    test('stores and retrieves data from memory cache', () async {
      const key = 'test_key';
      const value = {'data': 'test_value'};
      
      await cacheManager.set(key, value);
      final retrieved = await cacheManager.get(key);
      
      expect(retrieved, equals(value));
    });
    
    test('respects TTL for cached items', () async {
      const key = 'ttl_test';
      const value = {'data': 'expires'};
      
      await cacheManager.set(
        key, 
        value, 
        ttl: Duration(milliseconds: 100),
      );
      
      // Should exist immediately
      expect(await cacheManager.get(key), equals(value));
      
      // Wait for expiration
      await Future.delayed(Duration(milliseconds: 150));
      
      // Should be expired
      expect(await cacheManager.get(key), isNull);
    });
    
    test('removes items from cache', () async {
      const key = 'remove_test';
      const value = {'data': 'to_remove'};
      
      await cacheManager.set(key, value);
      expect(await cacheManager.get(key), equals(value));
      
      await cacheManager.remove(key);
      expect(await cacheManager.get(key), isNull);
    });
    
    test('clears all cached items', () async {
      await cacheManager.set('key1', {'data': 'value1'});
      await cacheManager.set('key2', {'data': 'value2'});
      await cacheManager.set('key3', {'data': 'value3'});
      
      await cacheManager.clear();
      
      expect(await cacheManager.get('key1'), isNull);
      expect(await cacheManager.get('key2'), isNull);
      expect(await cacheManager.get('key3'), isNull);
    });
    
    test('handles concurrent access', () async {
      const key = 'concurrent_test';
      
      // Simulate concurrent writes
      final futures = List.generate(10, (i) {
        return cacheManager.set(key, {'value': i});
      });
      
      await Future.wait(futures);
      
      // Should have last value
      final result = await cacheManager.get(key);
      expect(result, isNotNull);
      expect(result['value'], isA<int>());
    });
    
    test('persists data to storage', () async {
      const key = 'persist_test';
      const value = {'data': 'persistent'};
      
      await cacheManager.set(key, value, persistent: true);
      
      // Create new instance to simulate app restart
      final newCacheManager = CacheManager();
      
      // Should load from persistent storage
      final retrieved = await newCacheManager.get(key);
      expect(retrieved, equals(value));
    });
    
    test('evicts oldest items when cache is full', () async {
      // Fill cache beyond max size (100 items)
      for (int i = 0; i < 105; i++) {
        await cacheManager.set('item$i', {'value': i});
      }
      
      // First items should be evicted
      expect(await cacheManager.get('item0'), isNull);
      expect(await cacheManager.get('item1'), isNull);
      expect(await cacheManager.get('item2'), isNull);
      expect(await cacheManager.get('item3'), isNull);
      expect(await cacheManager.get('item4'), isNull);
      
      // Last items should still be in cache
      expect(await cacheManager.get('item100'), isNotNull);
      expect(await cacheManager.get('item101'), isNotNull);
      expect(await cacheManager.get('item102'), isNotNull);
      expect(await cacheManager.get('item103'), isNotNull);
      expect(await cacheManager.get('item104'), isNotNull);
    });
    
    test('provides cache statistics', () async {
      await cacheManager.set('key1', {'data': 'value1'});
      await cacheManager.set('key2', {'data': 'value2'});
      
      // Some hits and misses
      await cacheManager.get('key1'); // Hit
      await cacheManager.get('key1'); // Hit
      await cacheManager.get('key3'); // Miss
      
      final stats = cacheManager.getStatistics();
      
      expect(stats.memoryEntries, equals(2));
      expect(stats.hits, equals(2));
      expect(stats.misses, equals(1));
      expect(stats.hitRate, closeTo(0.67, 0.01));
    });
  });
  
  group('CachePolicy Tests', () {
    test('determines cacheable requests', () {
      final policy = CachePolicy(
        cachedEndpoints: {'/api', '/leads', '/jobs'},
      );
      
      expect(policy.shouldCache(
        RequestOptions(method: 'GET', path: '/api/users'),
      ), isTrue);
      expect(policy.shouldCache(
        RequestOptions(method: 'POST', path: '/api/users'),
      ), isFalse);
      expect(policy.shouldCache(
        RequestOptions(method: 'GET', path: '/uncached/path'),
      ), isFalse);
      
      // Test response caching
      expect(policy.shouldCacheResponse(
        Response(statusCode: 200, requestOptions: RequestOptions()),
      ), isTrue);
      expect(policy.shouldCacheResponse(
        Response(statusCode: 404, requestOptions: RequestOptions()),
      ), isFalse);
      expect(policy.shouldCacheResponse(
        Response(statusCode: 500, requestOptions: RequestOptions()),
      ), isFalse);
    });
    
    test('respects cache headers', () {
      final policy = CachePolicy();
      
      // Test cache-control header with max-age
      final responseWithCacheControl = Response(
        statusCode: 200,
        headers: Headers.fromMap({
          'cache-control': ['max-age=3600'],
        }),
        requestOptions: RequestOptions(),
      );
      
      expect(
        policy.shouldCacheResponse(responseWithCacheControl),
        isTrue,
      );
      
      // Test no-cache header
      final responseNoCache = Response(
        statusCode: 200,
        headers: Headers.fromMap({
          'cache-control': ['no-cache'],
        }),
        requestOptions: RequestOptions(),
      );
      
      expect(
        policy.shouldCacheResponse(responseNoCache),
        isFalse,
      );
      
      // Test no-store header
      final responseNoStore = Response(
        statusCode: 200,
        headers: Headers.fromMap({
          'cache-control': ['no-store'],
        }),
        requestOptions: RequestOptions(),
      );
      
      expect(
        policy.shouldCacheResponse(responseNoStore),
        isFalse,
      );
    });
    
    test('determines TTL for endpoints', () {
      final policy = CachePolicy();
      
      // Test default endpoint TTLs
      final leadsTtl = policy.getTtl(
        RequestOptions(path: '/leads/123'),
      );
      expect(leadsTtl, equals(Duration(minutes: 2)));
      
      final jobsTtl = policy.getTtl(
        RequestOptions(path: '/jobs/456'),
      );
      expect(jobsTtl, equals(Duration(seconds: 30)));
      
      // Test default TTL for unknown endpoints
      final unknownTtl = policy.getTtl(
        RequestOptions(path: '/unknown/path'),
      );
      expect(unknownTtl, equals(Duration(minutes: 5)));
      
      // Test cache-control header overrides
      final requestWithMaxAge = RequestOptions(
        path: '/api/data',
        headers: {'Cache-Control': 'max-age=7200'},
      );
      expect(
        policy.getTtl(requestWithMaxAge),
        equals(Duration(seconds: 7200)),
      );
    });
  });
}