// Integration between event system and Riverpod providers.
// Pattern: Provider Integration Pattern - connects events to state management.
// Single Responsibility: Event-provider bridge.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'event_bus.dart';
import 'domain_events.dart';
import 'event_handlers.dart';
import '../../features/leads/domain/entities/lead.dart';
import 'event_store.dart';
import 'event_replay.dart';

/// Provider for EventBus instance
final eventBusProvider = Provider<EventBus>((ref) {
  final bus = EventBus();
  ref.onDispose(() => bus.dispose());
  return bus;
});

/// Provider for EventStore
final eventStoreProvider = Provider<EventStore>((ref) {
  final store = EventStore();
  store.init(); // Initialize on creation
  return store;
});

/// Provider for EventReplayService
final eventReplayServiceProvider = Provider<EventReplayService>((ref) {
  final service = EventReplayService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for audit trail handler
final auditTrailHandlerProvider = Provider<AuditTrailHandler>((ref) {
  final handler = AuditTrailHandler();
  handler.startListening();
  ref.onDispose(() => handler.stopListening());
  return handler;
});

/// Provider for analytics handler
final analyticsHandlerProvider = Provider<AnalyticsHandler>((ref) {
  final handler = AnalyticsHandler();
  handler.startListening();
  ref.onDispose(() => handler.stopListening());
  return handler;
});

/// Provider for lead lifecycle handler
final leadLifecycleHandlerProvider = Provider<LeadLifecycleHandler>((ref) {
  final handler = LeadLifecycleHandler();
  handler.startListening();
  ref.onDispose(() => handler.stopListening());
  return handler;
});

/// Provider for error tracking handler
final errorTrackingHandlerProvider = Provider<ErrorTrackingHandler>((ref) {
  final handler = ErrorTrackingHandler();
  handler.startListening();
  ref.onDispose(() => handler.stopListening());
  return handler;
});

/// Provider for notification handler
final notificationHandlerProvider = Provider<NotificationHandler>((ref) {
  final handler = NotificationHandler();
  handler.startListening();
  ref.onDispose(() => handler.stopListening());
  return handler;
});

/// Stream provider for specific event types
final leadCreatedEventsProvider = StreamProvider<LeadCreatedEvent>((ref) {
  final bus = ref.watch(eventBusProvider);
  return bus.on<LeadCreatedEvent>();
});

final leadStatusChangedEventsProvider = StreamProvider<LeadStatusChangedEvent>((ref) {
  final bus = ref.watch(eventBusProvider);
  return bus.on<LeadStatusChangedEvent>();
});

final jobCompletedEventsProvider = StreamProvider<JobCompletedEvent>((ref) {
  final bus = ref.watch(eventBusProvider);
  return bus.on<JobCompletedEvent>();
});

final errorEventsProvider = StreamProvider<ErrorOccurredEvent>((ref) {
  final bus = ref.watch(eventBusProvider);
  return bus.on<ErrorOccurredEvent>();
});

/// Provider for replay status
final replayStatusProvider = StreamProvider<ReplayStatus>((ref) {
  final service = ref.watch(eventReplayServiceProvider);
  return service.replayStatus;
});

/// Mixin for event-aware state notifiers
mixin EventEmitter<T> on StateNotifier<T> {
  late EventBus _eventBus;
  
  void initEventBus(EventBus bus) {
    _eventBus = bus;
  }
  
  void emitEvent(AppEvent event) {
    _eventBus.fire(event);
  }
  
  Future<void> emitEventAsync(AppEvent event) async {
    await _eventBus.fireAsync(event);
  }
}

/// Base class for event-sourced state notifiers
abstract class EventSourcedStateNotifier<T> extends StateNotifier<T> {
  final EventBus _eventBus;
  final EventStore _eventStore;
  final List<StreamSubscription> _subscriptions = [];
  
  EventSourcedStateNotifier(
    T initialState,
    this._eventBus,
    this._eventStore,
  ) : super(initialState) {
    _setupEventListeners();
  }
  
  /// Setup event listeners - override in subclasses
  void _setupEventListeners();
  
  /// Listen to an event type
  void listenTo<E extends AppEvent>(void Function(E) handler) {
    final subscription = _eventBus.on<E>().listen(handler);
    _subscriptions.add(subscription);
  }
  
  /// Emit an event and store it
  void emit(AppEvent event) {
    _eventBus.fire(event);
    _eventStore.append(event);
  }
  
  /// Rebuild state from events
  Future<void> rebuildFromEvents() async {
    final events = _eventStore.getAllEvents();
    state = await computeStateFromEvents(events);
  }
  
  /// Compute state from event list - override in subclasses
  Future<T> computeStateFromEvents(List<AppEvent> events);
  
  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

/// Example event-sourced lead stats provider
class LeadStatsNotifier extends EventSourcedStateNotifier<LeadStats> {
  LeadStatsNotifier(EventBus bus, EventStore store) 
    : super(const LeadStats(), bus, store);
  
  @override
  void _setupEventListeners() {
    listenTo<LeadCreatedEvent>((event) {
      state = state.copyWith(totalLeads: state.totalLeads + 1);
    });
    
    listenTo<LeadStatusChangedEvent>((event) {
      if (event.newStatus == LeadStatus.converted) {
        state = state.copyWith(conversions: state.conversions + 1);
      }
    });
    
    listenTo<LeadDeletedEvent>((event) {
      state = state.copyWith(totalLeads: state.totalLeads - 1);
    });
  }
  
  @override
  Future<LeadStats> computeStateFromEvents(List<AppEvent> events) async {
    int totalLeads = 0;
    int conversions = 0;
    
    for (final event in events) {
      if (event is LeadCreatedEvent) {
        totalLeads++;
      } else if (event is LeadStatusChangedEvent) {
        if (event.newStatus == LeadStatus.converted) {
          conversions++;
        }
      } else if (event is LeadDeletedEvent) {
        totalLeads--;
      }
    }
    
    return LeadStats(
      totalLeads: totalLeads,
      conversions: conversions,
    );
  }
}

@immutable
class LeadStats {
  final int totalLeads;
  final int conversions;
  
  const LeadStats({
    this.totalLeads = 0,
    this.conversions = 0,
  });
  
  LeadStats copyWith({
    int? totalLeads,
    int? conversions,
  }) {
    return LeadStats(
      totalLeads: totalLeads ?? this.totalLeads,
      conversions: conversions ?? this.conversions,
    );
  }
  
  double get conversionRate => totalLeads > 0 
    ? conversions / totalLeads 
    : 0.0;
}

final leadStatsProvider = StateNotifierProvider<LeadStatsNotifier, LeadStats>((ref) {
  final bus = ref.watch(eventBusProvider);
  final store = ref.watch(eventStoreProvider);
  return LeadStatsNotifier(bus, store);
});