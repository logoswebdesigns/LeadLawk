// Cache manager for application data.
// Pattern: Cache-Aside Pattern with TTL Strategy.  
// Single Responsibility: Cache management and invalidation.

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Cache entry with metadata
class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final Duration ttl;
  final String? etag;
  
  CacheEntry({
    required this.data,
    required this.createdAt,
    required this.ttl,
    this.etag,
  });
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  DateTime get expiresAt => createdAt.add(ttl);
  Duration get remainingTtl => expiresAt.difference(DateTime.now());
  
  Map<String, dynamic> toJson() => {
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'ttl': ttl.inSeconds,
    'etag': etag,
  };
  
  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      data: json['data'] as T,
      createdAt: DateTime.parse(json['createdAt']),
      ttl: Duration(seconds: json['ttl'] as int),
      etag: json['etag'],
    );
  }
}

/// Cache manager with memory and persistent storage
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();
  
  // Memory cache
  final Map<String, CacheEntry> _memoryCache = {};
  
  // Cache configuration
  static const Duration defaultTtl = const Duration(minutes: 5);
  static const int maxMemoryCacheSize = 100;
  
  // Cache statistics
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  
  SharedPreferences? _prefs;
  
  /// Initialize cache manager
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPersistentCache();
  }
  
  /// Get item from cache
  Future<T?> get<T>(
    String key, {
    bool checkExpiry = true,
  }) async {
    // Check memory cache first
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null) {
      if (!checkExpiry || !memoryEntry.isExpired) {
        _hits++;
        if (kDebugMode) {
          debugPrint('Cache hit (memory): $key');
        }
        return memoryEntry.data as T;
      } else {
        // Remove expired entry
        _memoryCache.remove(key);
        _evictions++;
      }
    }
    
    // Check persistent cache
    final persistentData = await _getPersistent<T>(key);
    if (persistentData != null) {
      if (!checkExpiry || !persistentData.isExpired) {
        _hits++;
        // Promote to memory cache
        _memoryCache[key] = persistentData;
        if (kDebugMode) {
          debugPrint('Cache hit (persistent): $key');
        }
        return persistentData.data;
      } else {
        // Remove expired entry
        await _removePersistent(key);
        _evictions++;
      }
    }
    
    _misses++;
    if (kDebugMode) {
      debugPrint('Cache miss: $key');
    }
    return null;
  }
  
  /// Set item in cache
  Future<void> set<T>(
    String key,
    T data, {
    Duration? ttl,
    String? etag,
    bool persistent = false,
  }) async {
    final entry = CacheEntry<T>(
      data: data,
      createdAt: DateTime.now(),
      ttl: ttl ?? defaultTtl,
      etag: etag,
    );
    
    // Add to memory cache
    _memoryCache[key] = entry;
    _enforceMemoryCacheSize();
    
    // Add to persistent cache if requested
    if (persistent) {
      await _setPersistent(key, entry);
    }
    
    if (kDebugMode) {
      debugPrint('Cache set: $key (ttl: ${entry.ttl.inSeconds}s)');
    }
  }
  
  /// Remove item from cache
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    await _removePersistent(key);
    
    if (kDebugMode) {
      debugPrint('Cache removed: $key');
    }
  }
  
  /// Clear all cache
  Future<void> clear() async {
    _memoryCache.clear();
    await _clearPersistent();
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    
    if (kDebugMode) {
      debugPrint('Cache cleared');
    }
  }
  
  /// Clear expired entries
  Future<void> clearExpired() async {
    // Clear from memory
    final expiredKeys = _memoryCache.entries
      .where((e) => e.value.isExpired)
      .map((e) => e.key)
      .toList();
    
    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _evictions++;
    }
    
    // Clear from persistent storage
    await _clearExpiredPersistent();
    
    if (kDebugMode && expiredKeys.isNotEmpty) {
      debugPrint('Cleared ${expiredKeys.length} expired entries');
    }
  }
  
  /// Invalidate cache by pattern
  Future<void> invalidatePattern(String pattern) async {
    final regex = RegExp(pattern);
    
    // Invalidate memory cache
    final keysToRemove = _memoryCache.keys
      .where((key) => regex.hasMatch(key))
      .toList();
    
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }
    
    // Invalidate persistent cache
    await _invalidatePatternPersistent(pattern);
    
    if (kDebugMode && keysToRemove.isNotEmpty) {
      debugPrint('Invalidated ${keysToRemove.length} entries matching: $pattern');
    }
  }
  
  /// Get cache statistics
  CacheStatistics getStatistics() {
    final memorySize = _memoryCache.length;
    final hitRate = (_hits + _misses) > 0 
      ? _hits / (_hits + _misses) 
      : 0.0;
    
    return CacheStatistics(
      memoryEntries: memorySize,
      hits: _hits,
      misses: _misses,
      evictions: _evictions,
      hitRate: hitRate,
    );
  }
  
  /// Warm cache with data
  Future<void> warmCache(Map<String, dynamic> data) async {
    for (final entry in data.entries) {
      await set(entry.key, entry.value, persistent: true);
    }
    
    if (kDebugMode) {
      debugPrint('Cache warmed with ${data.length} entries');
    }
  }
  
  void _enforceMemoryCacheSize() {
    if (_memoryCache.length > maxMemoryCacheSize) {
      // Remove oldest entries (LRU)
      final sortedEntries = _memoryCache.entries.toList()
        ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));
      
      final toRemove = sortedEntries.take(
        _memoryCache.length - maxMemoryCacheSize
      );
      
      for (final entry in toRemove) {
        _memoryCache.remove(entry.key);
        _evictions++;
      }
    }
  }
  
  Future<CacheEntry<T>?> _getPersistent<T>(String key) async {
    if (_prefs == null) return null;
    
    final json = _prefs!.getString('cache_$key');
    if (json != null) {
      try {
        final data = jsonDecode(json);
        return CacheEntry<T>.fromJson(data);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to deserialize cache: $e');
        }
      }
    }
    return null;
  }
  
  Future<void> _setPersistent(String key, CacheEntry entry) async {
    if (_prefs == null) return;
    
    try {
      final json = jsonEncode(entry.toJson());
      await _prefs!.setString('cache_$key', json);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to persist cache: $e');
      }
    }
  }
  
  Future<void> _removePersistent(String key) async {
    await _prefs?.remove('cache_$key');
  }
  
  Future<void> _clearPersistent() async {
    if (_prefs == null) return;
    
    final keys = _prefs!.getKeys()
      .where((key) => key.startsWith('cache_'));
    
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }
  
  Future<void> _clearExpiredPersistent() async {
    if (_prefs == null) return;
    
    final keys = _prefs!.getKeys()
      .where((key) => key.startsWith('cache_'));
    
    for (final key in keys) {
      final json = _prefs!.getString(key);
      if (json != null) {
        try {
          final data = jsonDecode(json);
          final entry = CacheEntry.fromJson(data);
          if (entry.isExpired) {
            await _prefs!.remove(key);
            _evictions++;
          }
        } catch (_) {
          // Invalid entry, remove it
          await _prefs!.remove(key);
        }
      }
    }
  }
  
  Future<void> _invalidatePatternPersistent(String pattern) async {
    if (_prefs == null) return;
    
    final regex = RegExp(pattern);
    final keys = _prefs!.getKeys()
      .where((key) => key.startsWith('cache_') && 
                     regex.hasMatch(key.substring(6)));
    
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }
  
  Future<void> _loadPersistentCache() async {
    // Optionally load frequently accessed items into memory
    // This is a placeholder for app-specific logic
  }
}

/// Cache statistics
class CacheStatistics {
  final int memoryEntries;
  final int hits;
  final int misses;
  final int evictions;
  final double hitRate;
  
  const CacheStatistics({
    required this.memoryEntries,
    required this.hits,
    required this.misses,
    required this.evictions,
    required this.hitRate,
  });
  
  Map<String, dynamic> toJson() => {
    'memoryEntries': memoryEntries,
    'hits': hits,
    'misses': misses,
    'evictions': evictions,
    'hitRate': hitRate,
  };
}