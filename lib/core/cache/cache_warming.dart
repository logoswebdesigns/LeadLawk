// Cache warming service for preloading data.
// Pattern: Cache Warming Pattern - preloads frequently accessed data.
// Single Responsibility: Cache preloading on startup.

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'cache_manager.dart';
import '../network/dio_provider.dart';

/// Cache warming service for preloading data on startup
class CacheWarmingService {
  final CacheManager _cacheManager;
  final Dio _dio;
  final List<WarmingTask> _tasks = [];
  
  CacheWarmingService({
    CacheManager? cacheManager,
    Dio? dio,
  }) : _cacheManager = cacheManager ?? CacheManager(),
       _dio = dio ?? createDio();
  
  /// Register a warming task
  void registerTask(WarmingTask task) {
    _tasks.add(task);
  }
  
  /// Register default warming tasks
  void registerDefaultTasks() {
    // Settings and configuration
    registerTask(WarmingTask(
      name: 'Settings',
      endpoint: '/settings',
      ttl: const Duration(hours: 1),
      priority: 1,
      persistent: true,
    ));
    
    // Email templates
    registerTask(WarmingTask(
      name: 'Email Templates',
      endpoint: '/templates',
      ttl: Duration(minutes: 30),
      priority: 2,
      persistent: true,
    ));
    
    // Sales pitches
    registerTask(WarmingTask(
      name: 'Sales Pitches',
      endpoint: '/pitches',
      ttl: Duration(minutes: 30),
      priority: 2,
      persistent: true,
    ));
    
    // Recent leads
    registerTask(WarmingTask(
      name: 'Recent Leads',
      endpoint: '/leads?limit=20&sort=created_at&order=desc',
      ttl: Duration(minutes: 5),
      priority: 3,
    ));
    
    // Active jobs
    registerTask(WarmingTask(
      name: 'Active Jobs',
      endpoint: '/jobs?status=active',
      ttl: Duration(seconds: 30),
      priority: 3,
    ));
  }
  
  /// Warm the cache
  Future<WarmingResult> warmCache({
    bool parallel = true,
    Duration? timeout,
  }) async {
    final startTime = DateTime.now();
    final results = <TaskResult>[];
    
    if (kDebugMode) {
      debugPrint('Starting cache warming with ${_tasks.length} tasks');
    }
    
    // Sort tasks by priority
    final sortedTasks = List<WarmingTask>.from(_tasks)
      ..sort((a, b) => a.priority.compareTo(b.priority));
    
    if (parallel) {
      // Run tasks in parallel
      final futures = sortedTasks.map((task) => _warmTask(task));
      
      if (timeout != null) {
        final taskResults = await Future.wait(
          futures,
          eagerError: false,
        ).timeout(
          timeout,
          onTimeout: () => futures.map((_) => TaskResult.timeout()).toList(),
        );
        results.addAll(taskResults);
      } else {
        final taskResults = await Future.wait(
          futures,
          eagerError: false,
        );
        results.addAll(taskResults);
      }
    } else {
      // Run tasks sequentially
      for (final task in sortedTasks) {
        final result = await _warmTask(task);
        results.add(result);
      }
    }
    
    final duration = DateTime.now().difference(startTime);
    final successful = results.where((r) => r.success).length;
    final failed = results.where((r) => !r.success).length;
    
    if (kDebugMode) {
      debugPrint('Cache warming completed: $successful/${ _tasks.length} successful in ${duration.inMilliseconds}ms');
    }
    
    return WarmingResult(
      duration: duration,
      totalTasks: _tasks.length,
      successfulTasks: successful,
      failedTasks: failed,
      taskResults: results,
    );
  }
  
  Future<TaskResult> _warmTask(WarmingTask task) async {
    final startTime = DateTime.now();
    
    try {
      // Check if already cached
      final cacheKey = 'GET_${task.endpoint}';
      final cached = await _cacheManager.get(cacheKey);
      
      if (cached != null) {
        return TaskResult(
          taskName: task.name,
          success: true,
          fromCache: true,
          duration: DateTime.now().difference(startTime),
        );
      }
      
      // Fetch data
      final response = await _dio.get(task.endpoint);
      
      if (response.statusCode == 200) {
        // Cache the response
        await _cacheManager.set(
          cacheKey,
          {
            'data': response.data,
            'statusCode': response.statusCode,
            'headers': response.headers.map,
          },
          ttl: task.ttl,
          persistent: task.persistent,
        );
        
        return TaskResult(
          taskName: task.name,
          success: true,
          fromCache: false,
          duration: DateTime.now().difference(startTime),
        );
      } else {
        return TaskResult(
          taskName: task.name,
          success: false,
          error: 'HTTP ${response.statusCode}',
          duration: DateTime.now().difference(startTime),
        );
      }
    } catch (e) {
      return TaskResult(
        taskName: task.name,
        success: false,
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
      );
    }
  }
  
  /// Clear all warming tasks
  void clearTasks() {
    _tasks.clear();
  }
}

/// Warming task definition
class WarmingTask {
  final String name;
  final String endpoint;
  final Duration ttl;
  final int priority;
  final bool persistent;
  
  WarmingTask({
    required this.name,
    required this.endpoint,
    required this.ttl,
    this.priority = 5,
    this.persistent = false,
  });
}

/// Result of a warming task
class TaskResult {
  final String taskName;
  final bool success;
  final bool fromCache;
  final String? error;
  final Duration duration;
  
  TaskResult({
    required this.taskName,
    required this.success,
    this.fromCache = false,
    this.error,
    required this.duration,
  });
  
  factory TaskResult.timeout() {
    return TaskResult(
      taskName: 'Unknown',
      success: false,
      error: 'Timeout',
      duration: Duration.zero,
    );
  }
}

/// Overall warming result
class WarmingResult {
  final Duration duration;
  final int totalTasks;
  final int successfulTasks;
  final int failedTasks;
  final List<TaskResult> taskResults;
  
  WarmingResult({
    required this.duration,
    required this.totalTasks,
    required this.successfulTasks,
    required this.failedTasks,
    required this.taskResults,
  });
  
  double get successRate => totalTasks > 0 
    ? successfulTasks / totalTasks 
    : 0.0;
}