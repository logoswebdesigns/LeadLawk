// Event Bus for application-wide event communication.
// Pattern: Observer Pattern with Event Bus.
// Single Responsibility: Event distribution and subscription management.

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Base class for all application events
@immutable
abstract class AppEvent {
  final DateTime timestamp;
  final String? userId;
  final Map<String, dynamic>? metadata;
  
  AppEvent({
    DateTime? timestamp,
    this.userId,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();
  
  String get eventType => runtimeType.toString();
  
  Map<String, dynamic> toJson() => {
    'eventType': eventType,
    'timestamp': timestamp.toIso8601String(),
    'userId': userId,
    'metadata': metadata,
  };
}

/// Event Bus for application-wide event distribution
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();
  
  final Map<Type, List<StreamController>> _subscribers = {};
  final List<AppEvent> _eventHistory = [];
  final int _maxHistorySize = 1000;
  
  // Global event stream for monitoring
  final _globalEventController = StreamController<AppEvent>.broadcast();
  Stream<AppEvent> get globalEventStream => _globalEventController.stream;
  
  /// Subscribe to events of a specific type
  Stream<T> on<T extends AppEvent>() {
    final controller = StreamController<T>.broadcast();
    
    _subscribers.putIfAbsent(T, () => []).add(controller);
    
    // Cleanup when stream is closed
    controller.onCancel = () {
      _subscribers[T]?.remove(controller);
      if (_subscribers[T]?.isEmpty ?? false) {
        _subscribers.remove(T);
      }
    };
    
    return controller.stream;
  }
  
  /// Publish an event to all subscribers
  void fire<T extends AppEvent>(T event) {
    // Add to history
    _addToHistory(event);
    
    // Notify global listeners
    _globalEventController.add(event);
    
    // Notify specific type listeners
    final subscribers = _subscribers[T];
    if (subscribers != null) {
      for (final controller in subscribers) {
        if (!controller.isClosed) {
          controller.add(event);
        }
      }
    }
    
    // Log in debug mode
    if (kDebugMode) {
      debugPrint('Event fired: ${event.eventType}');
    }
  }
  
  /// Fire an event and wait for handlers to complete
  Future<void> fireAsync<T extends AppEvent>(T event) async {
    fire(event);
    // Allow event loop to process
    await Future.delayed(Duration.zero);
  }
  
  void _addToHistory(AppEvent event) {
    _eventHistory.add(event);
    if (_eventHistory.length > _maxHistorySize) {
      _eventHistory.removeAt(0);
    }
  }
  
  /// Get event history for debugging/replay
  List<AppEvent> getHistory({
    DateTime? since,
    String? eventType,
    String? userId,
  }) {
    var history = _eventHistory.toList();
    
    if (since != null) {
      history = history.where((e) => e.timestamp.isAfter(since)).toList();
    }
    
    if (eventType != null) {
      history = history.where((e) => e.eventType == eventType).toList();
    }
    
    if (userId != null) {
      history = history.where((e) => e.userId == userId).toList();
    }
    
    return history;
  }
  
  /// Clear all event history
  void clearHistory() {
    _eventHistory.clear();
  }
  
  /// Dispose of resources
  void dispose() {
    for (final controllers in _subscribers.values) {
      for (final controller in controllers) {
        controller.close();
      }
    }
    _subscribers.clear();
    _globalEventController.close();
    _eventHistory.clear();
  }
}