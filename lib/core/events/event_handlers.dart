// Event handlers for domain events.
// Pattern: Command Handler Pattern - processes domain events.
// Single Responsibility: Event processing logic.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'event_bus.dart';
import 'domain_events.dart';
import 'event_store.dart';
import '../../features/leads/domain/entities/lead.dart';

/// Base class for event handlers
abstract class EventHandler<T extends AppEvent> {
  StreamSubscription<T>? _subscription;
  
  void startListening() {
    _subscription = EventBus().on<T>().listen(handle);
  }
  
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
  
  Future<void> handle(T event);
}

/// Audit trail handler - logs all events
class AuditTrailHandler extends EventHandler<AppEvent> {
  final EventStore _eventStore = EventStore();
  
  @override
  void startListening() {
    // Listen to global event stream for all events
    _subscription = EventBus().globalEventStream.listen(handle);
  }
  
  @override
  Future<void> handle(AppEvent event) async {
    // Store event for audit trail
    await _eventStore.append(event);
    
    if (kDebugMode) {
      debugPrint('Audit: ${event.eventType} at ${event.timestamp}');
    }
  }
}

/// Analytics event handler
class AnalyticsHandler extends EventHandler<AppEvent> {
  final Map<String, int> _eventCounts = {};
  final Map<String, DateTime> _lastEventTime = {};
  
  @override
  void startListening() {
    _subscription = EventBus().globalEventStream.listen(handle);
  }
  
  @override
  Future<void> handle(AppEvent event) async {
    // Track event counts
    _eventCounts[event.eventType] = (_eventCounts[event.eventType] ?? 0) + 1;
    _lastEventTime[event.eventType] = event.timestamp;
    
    // Send to analytics service (placeholder)
    await _sendToAnalytics(event);
  }
  
  Future<void> _sendToAnalytics(AppEvent event) async {
    // Implementation would send to actual analytics service
    if (kDebugMode) {
      debugPrint('Analytics: ${event.eventType}');
    }
  }
  
  Map<String, dynamic> getStatistics() => {
    'eventCounts': _eventCounts,
    'lastEventTimes': _lastEventTime.map(
      (k, v) => MapEntry(k, v.toIso8601String())
    ),
  };
}

/// Lead lifecycle handler
class LeadLifecycleHandler {
  StreamSubscription? _createdSub;
  StreamSubscription? _statusChangedSub;
  StreamSubscription? _deletedSub;
  
  void startListening() {
    final bus = EventBus();
    
    _createdSub = bus.on<LeadCreatedEvent>().listen(_handleLeadCreated);
    _statusChangedSub = bus.on<LeadStatusChangedEvent>().listen(_handleStatusChanged);
    _deletedSub = bus.on<LeadDeletedEvent>().listen(_handleLeadDeleted);
  }
  
  void stopListening() {
    _createdSub?.cancel();
    _statusChangedSub?.cancel();
    _deletedSub?.cancel();
  }
  
  Future<void> _handleLeadCreated(LeadCreatedEvent event) async {
    // Trigger welcome workflow
    if (kDebugMode) {
      debugPrint('Lead created: ${event.businessName}');
    }
    
    // Could trigger additional actions like:
    // - Send notification
    // - Update statistics
    // - Trigger automation
  }
  
  Future<void> _handleStatusChanged(LeadStatusChangedEvent event) async {
    // Handle status-specific workflows
    if (event.newStatus == LeadStatus.converted) {
      // Trigger conversion celebration
      if (kDebugMode) {
        debugPrint('Lead converted: ${event.leadId}');
      }
    } else if (event.newStatus == LeadStatus.doNotCall) {
      // Handle DNC workflow
      if (kDebugMode) {
        debugPrint('Lead marked DNC: ${event.leadId}');
      }
    }
  }
  
  Future<void> _handleLeadDeleted(LeadDeletedEvent event) async {
    // Clean up related data
    if (kDebugMode) {
      debugPrint('Lead deleted: ${event.leadId}');
    }
  }
}

/// Error tracking handler
class ErrorTrackingHandler extends EventHandler<ErrorOccurredEvent> {
  final List<ErrorOccurredEvent> _recentErrors = [];
  final int _maxErrors = 100;
  
  @override
  Future<void> handle(ErrorOccurredEvent event) async {
    _recentErrors.add(event);
    if (_recentErrors.length > _maxErrors) {
      _recentErrors.removeAt(0);
    }
    
    // Log error for debugging
    if (kDebugMode) {
      debugPrint('Error in ${event.context}: ${event.error}');
      if (event.stackTrace != null) {
        debugPrint('Stack trace: ${event.stackTrace}');
      }
    }
    
    // Could send to error tracking service like Sentry
    await _reportError(event);
  }
  
  Future<void> _reportError(ErrorOccurredEvent event) async {
    // Placeholder for error reporting service
  }
  
  List<ErrorOccurredEvent> getRecentErrors() => List.from(_recentErrors);
}

/// Notification handler for important events
class NotificationHandler {
  StreamSubscription? _jobCompletedSub;
  StreamSubscription? _leadConvertedSub;
  
  void startListening() {
    final bus = EventBus();
    
    _jobCompletedSub = bus.on<JobCompletedEvent>().listen(_handleJobCompleted);
    _leadConvertedSub = bus.on<LeadStatusChangedEvent>()
      .where((e) => e.newStatus == LeadStatus.converted)
      .listen(_handleLeadConverted);
  }
  
  void stopListening() {
    _jobCompletedSub?.cancel();
    _leadConvertedSub?.cancel();
  }
  
  Future<void> _handleJobCompleted(JobCompletedEvent event) async {
    // Show notification for job completion
    if (kDebugMode) {
      debugPrint('Job ${event.jobId} completed with ${event.leadsFound} leads');
    }
  }
  
  Future<void> _handleLeadConverted(LeadStatusChangedEvent event) async {
    // Show celebration notification
    if (kDebugMode) {
      debugPrint('🎉 Lead converted: ${event.leadId}');
    }
  }
}