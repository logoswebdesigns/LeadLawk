import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Cache entry with TTL support
class CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final Duration ttl;

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().isAfter(timestamp.add(ttl));

  Map<String, dynamic> toJson() => {
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'ttl_seconds': ttl.inSeconds,
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
    data: json['data'],
    timestamp: DateTime.parse(json['timestamp']),
    ttl: Duration(seconds: json['ttl_seconds']),
  );
}

/// High-performance cache manager with in-memory and persistent storage
class CacheManager {
  static CacheManager? _instance;
  static CacheManager get instance => _instance ??= CacheManager._();
  
  CacheManager._();

  final Map<String, CacheEntry> _memoryCache = {};
  Box<String>? _persistentCache;
  Timer? _cleanupTimer;

  /// Initialize cache manager
  Future<void> init() async {
    await Hive.initFlutter();
    _persistentCache = await Hive.openBox<String>('repository_cache');
    
    // Start periodic cleanup every 5 minutes
    _cleanupTimer = Timer.periodic(
      Duration(minutes: 5),
      (_) => _cleanup(),
    );
  }

  /// Store data in cache with TTL
  Future<void> set(String key, dynamic data, Duration ttl) async {
    final entry = CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      ttl: ttl,
    );
    
    // Store in memory cache
    _memoryCache[key] = entry;
    
    // Store in persistent cache if available
    if (_persistentCache != null) {
      try {
        await _persistentCache!.put(key, jsonEncode(entry.toJson()));
      } catch (e) {
        // Ignore persistent cache errors
      }
    }
  }

  /// Get data from cache
  T? get<T>(String key) {
    // Try memory cache first
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null) {
      if (!memoryEntry.isExpired) {
        return memoryEntry.data as T?;
      } else {
        _memoryCache.remove(key);
      }
    }

    // Try persistent cache
    if (_persistentCache != null) {
      try {
        final cached = _persistentCache!.get(key);
        if (cached != null) {
          final entry = CacheEntry.fromJson(jsonDecode(cached));
          if (!entry.isExpired) {
            // Promote to memory cache
            _memoryCache[key] = entry;
            return entry.data as T?;
          } else {
            _persistentCache!.delete(key);
          }
        }
      } catch (e) {
        // Ignore persistent cache errors
        _persistentCache?.delete(key);
      }
    }

    return null;
  }

  /// Check if key exists in cache
  bool contains(String key) => get(key) != null;

  /// Remove specific key from cache
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    await _persistentCache?.delete(key);
  }

  /// Remove all keys with prefix
  Future<void> removeByPrefix(String prefix) async {
    // Remove from memory cache
    final keysToRemove = _memoryCache.keys
        .where((key) => key.startsWith(prefix))
        .toList();
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }

    // Remove from persistent cache
    if (_persistentCache != null) {
      final persistentKeys = _persistentCache!.keys
          .where((key) => key.toString().startsWith(prefix))
          .toList();
      for (final key in persistentKeys) {
        await _persistentCache!.delete(key);
      }
    }
  }

  /// Clear all cache
  Future<void> clear() async {
    _memoryCache.clear();
    await _persistentCache?.clear();
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'memory_entries': _memoryCache.length,
      'persistent_entries': _persistentCache?.length ?? 0,
      'memory_size_bytes': _calculateMemorySize(),
    };
  }

  /// Clean up expired entries
  void _cleanup() {
    // Clean memory cache
    final expiredKeys = _memoryCache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _memoryCache.remove(key);
    }

    // Clean persistent cache (async)
    _cleanupPersistentCache();
  }

  /// Clean persistent cache asynchronously
  Future<void> _cleanupPersistentCache() async {
    if (_persistentCache == null) return;

    try {
      final keys = _persistentCache!.keys.toList();
      for (final key in keys) {
        final cached = _persistentCache!.get(key);
        if (cached != null) {
          try {
            final entry = CacheEntry.fromJson(jsonDecode(cached));
            if (entry.isExpired) {
              await _persistentCache!.delete(key);
            }
          } catch (e) {
            // Remove corrupted entries
            await _persistentCache!.delete(key);
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Calculate approximate memory usage
  int _calculateMemorySize() {
    var size = 0;
    for (final entry in _memoryCache.values) {
      size += entry.toString().length * 2; // Rough estimate
    }
    return size;
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _persistentCache?.close();
  }
}