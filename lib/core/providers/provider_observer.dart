// Provider observer for debugging and monitoring.
// Pattern: Observer Pattern - monitors provider lifecycle.
// Single Responsibility: Provider debugging and analytics.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../events/event_bus.dart';
import '../events/domain_events.dart';

/// Custom provider observer for debugging and monitoring
class AppProviderObserver extends ProviderObserver {
  final EventBus? _eventBus;
  final bool _enableLogging;
  final Map<String, ProviderMetrics> _metrics = {};
  
  AppProviderObserver({
    EventBus? eventBus,
    bool enableLogging = kDebugMode,
  }) : _eventBus = eventBus,
       _enableLogging = enableLogging;
  
  @override
  void didAddProvider(
    ProviderBase provider,
    Object? value,
    ProviderContainer container,
  ) {
    if (_enableLogging) {
      debugPrint('Provider added: ${provider.name ?? provider.runtimeType}');
    }
    
    _metrics[_getProviderKey(provider)] = ProviderMetrics(
      createdAt: DateTime.now(),
    );
  }
  
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (_enableLogging) {
      debugPrint('Provider updated: ${provider.name ?? provider.runtimeType}');
    }
    
    final key = _getProviderKey(provider);
    final metrics = _metrics[key];
    if (metrics != null) {
      metrics.updateCount++;
      metrics.lastUpdated = DateTime.now();
    }
  }
  
  @override
  void didDisposeProvider(
    ProviderBase provider,
    ProviderContainer container,
  ) {
    if (_enableLogging) {
      debugPrint('Provider disposed: ${provider.name ?? provider.runtimeType}');
    }
    
    final key = _getProviderKey(provider);
    final metrics = _metrics[key];
    if (metrics != null) {
      metrics.disposedAt = DateTime.now();
      
      // Log lifetime metrics
      if (_enableLogging) {
        final lifetime = metrics.disposedAt!.difference(metrics.createdAt);
        debugPrint('Provider lifetime: $lifetime, updates: ${metrics.updateCount}');
      }
    }
  }
  
  @override
  void providerDidFail(
    ProviderBase provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    if (_enableLogging) {
      debugPrint('Provider failed: ${provider.name ?? provider.runtimeType}');
      debugPrint('Error: $error');
    }
    
    // Fire error event
    _eventBus?.fire(ErrorOccurredEvent(
      error: error.toString(),
      stackTrace: stackTrace.toString(),
      context: 'Provider: ${provider.name ?? provider.runtimeType}',
    ));
    
    final key = _getProviderKey(provider);
    final metrics = _metrics[key];
    if (metrics != null) {
      metrics.errorCount++;
      metrics.lastError = error.toString();
    }
  }
  
  String _getProviderKey(ProviderBase provider) {
    return provider.name ?? provider.runtimeType.toString();
  }
  
  /// Get metrics for all providers
  Map<String, ProviderMetrics> getMetrics() => Map.from(_metrics);
  
  /// Get metrics for a specific provider
  ProviderMetrics? getProviderMetrics(String providerName) {
    return _metrics[providerName];
  }
  
  /// Clear all metrics
  void clearMetrics() {
    _metrics.clear();
  }
  
  /// Export metrics report
  Map<String, dynamic> exportReport() {
    final report = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'totalProviders': _metrics.length,
      'activeProviders': _metrics.values.where((m) => m.disposedAt == null).length,
      'totalUpdates': _metrics.values.fold(0, (sum, m) => sum + m.updateCount),
      'totalErrors': _metrics.values.fold(0, (sum, m) => sum + m.errorCount),
      'providers': _metrics.map((key, value) => MapEntry(key, value.toJson())),
    };
    
    return report;
  }
}

/// Metrics for individual providers
class ProviderMetrics {
  final DateTime createdAt;
  DateTime? disposedAt;
  DateTime? lastUpdated;
  int updateCount = 0;
  int errorCount = 0;
  String? lastError;
  
  ProviderMetrics({
    required this.createdAt,
  });
  
  Duration get lifetime => (disposedAt ?? DateTime.now()).difference(createdAt);
  
  bool get isActive => disposedAt == null;
  
  Map<String, dynamic> toJson() => {
    'createdAt': createdAt.toIso8601String(),
    'disposedAt': disposedAt?.toIso8601String(),
    'lastUpdated': lastUpdated?.toIso8601String(),
    'updateCount': updateCount,
    'errorCount': errorCount,
    'lastError': lastError,
    'lifetime': lifetime.inMilliseconds,
    'isActive': isActive,
  };
}

/// Global provider observer instance
AppProviderObserver? _globalObserver;

/// Initialize the global provider observer
AppProviderObserver initializeProviderObserver({
  EventBus? eventBus,
  bool enableLogging = kDebugMode,
}) {
  _globalObserver = AppProviderObserver(
    eventBus: eventBus,
    enableLogging: enableLogging,
  );
  return _globalObserver!;
}

/// Get the global provider observer
AppProviderObserver? getProviderObserver() => _globalObserver;