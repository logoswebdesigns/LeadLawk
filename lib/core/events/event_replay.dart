// Event replay mechanism for debugging and recovery.
// Pattern: Event Replay Pattern - reconstructs state from events.
// Single Responsibility: Event replay and state reconstruction.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'event_bus.dart';
import 'event_store.dart';

/// Event replay service for debugging and recovery
class EventReplayService {
  final EventStore _eventStore = EventStore();
  final EventBus _eventBus = EventBus();
  
  bool _isReplaying = false;
  StreamController<ReplayStatus>? _replayStatusController;
  
  /// Get replay status stream
  Stream<ReplayStatus> get replayStatus {
    _replayStatusController ??= StreamController<ReplayStatus>.broadcast();
    return _replayStatusController!.stream;
  }
  
  /// Check if replay is in progress
  bool get isReplaying => _isReplaying;
  
  /// Replay all events from beginning
  Future<ReplayResult> replayAll({
    Duration delay = const Duration(milliseconds: 10),
    bool Function(AppEvent)? filter,
  }) async {
    if (_isReplaying) {
      return ReplayResult(
        success: false,
        error: 'Replay already in progress',
      );
    }
    
    _isReplaying = true;
    final events = _eventStore.getAllEvents();
    final eventsToReplay = filter != null 
      ? events.where(filter).toList()
      : events;
    
    return _performReplay(eventsToReplay, delay);
  }
  
  /// Replay events from a specific point
  Future<ReplayResult> replayFrom({
    required DateTime from,
    DateTime? to,
    Duration delay = const Duration(milliseconds: 10),
    bool Function(AppEvent)? filter,
  }) async {
    if (_isReplaying) {
      return ReplayResult(
        success: false,
        error: 'Replay already in progress',
      );
    }
    
    _isReplaying = true;
    final events = _eventStore.getEventsByTimeRange(
      from,
      to ?? DateTime.now(),
    );
    final eventsToReplay = filter != null 
      ? events.where(filter).toList()
      : events;
    
    return _performReplay(eventsToReplay, delay);
  }
  
  /// Replay events for a specific entity
  Future<ReplayResult> replayForEntity({
    required String entityId,
    required String entityType,
    Duration delay = const Duration(milliseconds: 10),
  }) async {
    if (_isReplaying) {
      return ReplayResult(
        success: false,
        error: 'Replay already in progress',
      );
    }
    
    _isReplaying = true;
    final events = _eventStore.getEventsForEntity(entityId, entityType);
    
    return _performReplay(events, delay);
  }
  
  /// Perform the actual replay
  Future<ReplayResult> _performReplay(
    List<AppEvent> events,
    Duration delay,
  ) async {
    final startTime = DateTime.now();
    int processed = 0;
    final errors = <String>[];
    
    try {
      _notifyStatus(ReplayStatus(
        isReplaying: true,
        totalEvents: events.length,
        processedEvents: 0,
        startTime: startTime,
      ));
      
      for (final event in events) {
        try {
          _eventBus.fire(event);
          processed++;
          
          _notifyStatus(ReplayStatus(
            isReplaying: true,
            totalEvents: events.length,
            processedEvents: processed,
            currentEvent: event,
            startTime: startTime,
          ));
          
          await Future.delayed(delay);
        } catch (e) {
          errors.add('Failed to replay ${event.eventType}: $e');
          if (kDebugMode) {
            debugPrint('Replay error: $e');
          }
        }
      }
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      _notifyStatus(ReplayStatus(
        isReplaying: false,
        totalEvents: events.length,
        processedEvents: processed,
        startTime: startTime,
        endTime: endTime,
      ));
      
      return ReplayResult(
        success: errors.isEmpty,
        eventsReplayed: processed,
        duration: duration,
        errors: errors.isEmpty ? null : errors,
      );
      
    } catch (e) {
      return ReplayResult(
        success: false,
        error: e.toString(),
        eventsReplayed: processed,
      );
    } finally {
      _isReplaying = false;
    }
  }
  
  /// Simulate replay without actually firing events
  Future<ReplayResult> dryRun({
    DateTime? from,
    DateTime? to,
    bool Function(AppEvent)? filter,
  }) async {
    final events = from != null
      ? _eventStore.getEventsByTimeRange(from, to ?? DateTime.now())
      : _eventStore.getAllEvents();
    
    final eventsToReplay = filter != null 
      ? events.where(filter).toList()
      : events;
    
    // Analyze what would be replayed
    final eventTypes = <String, int>{};
    for (final event in eventsToReplay) {
      eventTypes[event.eventType] = (eventTypes[event.eventType] ?? 0) + 1;
    }
    
    return ReplayResult(
      success: true,
      eventsReplayed: eventsToReplay.length,
      isDryRun: true,
      metadata: {
        'eventTypes': eventTypes,
        'timeRange': {
          'from': eventsToReplay.firstOrNull?.timestamp.toIso8601String(),
          'to': eventsToReplay.lastOrNull?.timestamp.toIso8601String(),
        },
      },
    );
  }
  
  void _notifyStatus(ReplayStatus status) {
    _replayStatusController?.add(status);
  }
  
  /// Dispose resources
  void dispose() {
    _replayStatusController?.close();
    _replayStatusController = null;
  }
}

/// Replay status information
@immutable
class ReplayStatus {
  final bool isReplaying;
  final int totalEvents;
  final int processedEvents;
  final AppEvent? currentEvent;
  final DateTime startTime;
  final DateTime? endTime;
  
  const ReplayStatus({
    required this.isReplaying,
    required this.totalEvents,
    required this.processedEvents,
    this.currentEvent,
    required this.startTime,
    this.endTime,
  });
  
  double get progress => totalEvents > 0 
    ? processedEvents / totalEvents 
    : 0.0;
  
  Duration? get elapsed => endTime?.difference(startTime) 
    ?? DateTime.now().difference(startTime);
}

/// Result of a replay operation
@immutable
class ReplayResult {
  final bool success;
  final int eventsReplayed;
  final Duration? duration;
  final String? error;
  final List<String>? errors;
  final bool isDryRun;
  final Map<String, dynamic>? metadata;
  
  const ReplayResult({
    required this.success,
    this.eventsReplayed = 0,
    this.duration,
    this.error,
    this.errors,
    this.isDryRun = false,
    this.metadata,
  });
}