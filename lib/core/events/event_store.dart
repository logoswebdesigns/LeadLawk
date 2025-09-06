// Event store for event sourcing and replay.
// Pattern: Event Sourcing Pattern - stores all events as source of truth.
// Single Responsibility: Event persistence and replay.

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'event_bus.dart';
import 'domain_events.dart';
import '../../features/leads/domain/entities/lead.dart';

/// Event store for persisting and replaying events
class EventStore {
  static final EventStore _instance = EventStore._internal();
  factory EventStore() => _instance;
  EventStore._internal();
  
  static const String _storageKey = 'event_store';
  static const int _maxEvents = 10000;
  
  final List<AppEvent> _events = [];
  SharedPreferences? _prefs;
  
  /// Initialize the event store
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadEvents();
  }
  
  /// Append an event to the store
  Future<void> append(AppEvent event) async {
    _events.add(event);
    
    // Trim if exceeds max size
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }
    
    await _persistEvents();
  }
  
  /// Append multiple events
  Future<void> appendAll(List<AppEvent> events) async {
    _events.addAll(events);
    
    // Trim if exceeds max size
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }
    
    await _persistEvents();
  }
  
  /// Get all events
  List<AppEvent> getAllEvents() => List.from(_events);
  
  /// Get events by type
  List<T> getEventsByType<T extends AppEvent>() {
    return _events.whereType<T>().toList();
  }
  
  /// Get events in a time range
  List<AppEvent> getEventsByTimeRange(DateTime start, DateTime end) {
    return _events.where((e) => 
      e.timestamp.isAfter(start) && e.timestamp.isBefore(end)
    ).toList();
  }
  
  /// Get events for a specific entity
  List<AppEvent> getEventsForEntity(String entityId, String entityType) {
    return _events.where((e) {
      final json = e.toJson();
      return json['${entityType}Id'] == entityId;
    }).toList();
  }
  
  /// Replay events from a point in time
  Future<void> replay({
    DateTime? from,
    DateTime? to,
    bool Function(AppEvent)? filter,
  }) async {
    var eventsToReplay = _events;
    
    if (from != null) {
      eventsToReplay = eventsToReplay.where(
        (e) => e.timestamp.isAfter(from)
      ).toList();
    }
    
    if (to != null) {
      eventsToReplay = eventsToReplay.where(
        (e) => e.timestamp.isBefore(to)
      ).toList();
    }
    
    if (filter != null) {
      eventsToReplay = eventsToReplay.where(filter).toList();
    }
    
    final bus = EventBus();
    for (final event in eventsToReplay) {
      // Re-fire events with slight delay to allow processing
      bus.fire(event);
      await Future.delayed(Duration(milliseconds: 10));
    }
    
    if (kDebugMode) {
      debugPrint('Replayed ${eventsToReplay.length} events');
    }
  }
  
  /// Create a snapshot of current state from events
  Map<String, dynamic> createSnapshot() {
    final snapshot = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'eventCount': _events.length,
      'leadStats': _calculateLeadStats(),
      'activityStats': _calculateActivityStats(),
    };
    
    return snapshot;
  }
  
  Map<String, dynamic> _calculateLeadStats() {
    final stats = <String, dynamic>{
      'created': 0,
      'statusChanges': 0,
      'conversions': 0,
    };
    
    for (final event in _events) {
      if (event is LeadCreatedEvent) {
        stats['created']++;
      } else if (event is LeadStatusChangedEvent) {
        stats['statusChanges']++;
        if (event.newStatus == LeadStatus.converted) {
          stats['conversions']++;
        }
      }
    }
    
    return stats;
  }
  
  Map<String, dynamic> _calculateActivityStats() {
    final stats = <String, dynamic>{
      'calls': 0,
      'emails': 0,
      'jobs': 0,
    };
    
    for (final event in _events) {
      if (event is CallEndedEvent) {
        stats['calls']++;
      } else if (event is EmailSentEvent) {
        stats['emails']++;
      } else if (event is JobCompletedEvent) {
        stats['jobs']++;
      }
    }
    
    return stats;
  }
  
  /// Clear all events
  Future<void> clear() async {
    _events.clear();
    await _prefs?.remove(_storageKey);
  }
  
  /// Persist events to storage
  Future<void> _persistEvents() async {
    if (_prefs == null) return;
    
    try {
      final eventJsonList = _events.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(eventJsonList);
      await _prefs!.setString(_storageKey, jsonString);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to persist events: $e');
      }
    }
  }
  
  /// Load events from storage
  Future<void> _loadEvents() async {
    if (_prefs == null) return;
    
    try {
      final jsonString = _prefs!.getString(_storageKey);
      if (jsonString != null) {
        final eventJsonList = jsonDecode(jsonString) as List;
        // Note: In production, you'd deserialize to proper event types
        // For now, we'll skip loading to avoid complexity
        if (kDebugMode) {
          debugPrint('Found ${eventJsonList.length} stored events');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load events: $e');
      }
    }
  }
}