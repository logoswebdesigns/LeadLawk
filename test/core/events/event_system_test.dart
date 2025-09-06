//
// Tests for event-driven architecture.
// Pattern: Unit Testing - verifies event system functionality.
//

import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/core/events/event_bus.dart';
import 'package:leadloq/core/events/domain_events.dart';
import 'package:leadloq/core/events/event_store.dart';
import 'package:leadloq/core/events/event_replay.dart';
import 'package:leadloq/core/events/event_handlers.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';

void main() {
  group('EventBus Tests', () {
    late EventBus eventBus;
    
    setUp(() {
      eventBus = EventBus();
    });
    
    tearDown(() {
      eventBus.dispose();
    });
    
    test('should fire and receive events', () async {
      final receivedEvents = <LeadCreatedEvent>[];
      
      final subscription = eventBus.on<LeadCreatedEvent>().listen((event) {
        receivedEvents.add(event);
      });
      
      final event = LeadCreatedEvent(
        leadId: 'test-1',
        businessName: 'Test Business',
        industry: 'Tech',
        location: 'Test City',
      );
      
      eventBus.fire(event);
      
      await Future.delayed(Duration(milliseconds: 10));
      
      expect(receivedEvents.length, 1);
      expect(receivedEvents.first.leadId, 'test-1');
      
      subscription.cancel();
    });
    
    test('should handle multiple subscribers', () async {
      int subscriber1Count = 0;
      int subscriber2Count = 0;
      
      final sub1 = eventBus.on<LeadCreatedEvent>().listen((_) {
        subscriber1Count++;
      });
      
      final sub2 = eventBus.on<LeadCreatedEvent>().listen((_) {
        subscriber2Count++;
      });
      
      eventBus.fire(LeadCreatedEvent(
        leadId: 'test-2',
        businessName: 'Test',
        industry: 'Tech',
        location: 'City',
      ));
      
      await Future.delayed(Duration(milliseconds: 10));
      
      expect(subscriber1Count, 1);
      expect(subscriber2Count, 1);
      
      sub1.cancel();
      sub2.cancel();
    });
    
    test('should maintain event history', () {
      final event1 = LeadCreatedEvent(
        leadId: 'test-1',
        businessName: 'Business 1',
        industry: 'Tech',
        location: 'City',
      );
      
      final event2 = LeadStatusChangedEvent(
        leadId: 'test-1',
        oldStatus: LeadStatus.new_,
        newStatus: LeadStatus.called,
      );
      
      eventBus.fire(event1);
      eventBus.fire(event2);
      
      final history = eventBus.getHistory();
      
      expect(history.length, 2);
      expect(history[0], event1);
      expect(history[1], event2);
    });
    
    test('should filter history by event type', () {
      eventBus.fire(LeadCreatedEvent(
        leadId: 'test-1',
        businessName: 'Business',
        industry: 'Tech',
        location: 'City',
      ));
      
      eventBus.fire(LeadStatusChangedEvent(
        leadId: 'test-1',
        oldStatus: LeadStatus.new_,
        newStatus: LeadStatus.called,
      ));
      
      final filteredHistory = eventBus.getHistory(
        eventType: 'LeadCreatedEvent',
      );
      
      expect(filteredHistory.length, 1);
      expect(filteredHistory[0] is LeadCreatedEvent, true);
    });
  });
  
  group('EventStore Tests', () {
    late EventStore eventStore;
    
    setUp(() async {
      eventStore = EventStore();
      await eventStore.init();
    });
    
    tearDown(() async {
      await eventStore.clear();
    });
    
    test('should store and retrieve events', () async {
      final event = LeadCreatedEvent(
        leadId: 'test-1',
        businessName: 'Test Business',
        industry: 'Tech',
        location: 'City',
      );
      
      await eventStore.append(event);
      
      final events = eventStore.getAllEvents();
      expect(events.length, 1);
      expect(events[0], event);
    });
    
    test('should get events by type', () async {
      await eventStore.appendAll([
        LeadCreatedEvent(
          leadId: 'test-1',
          businessName: 'Business 1',
          industry: 'Tech',
          location: 'City',
        ),
        LeadStatusChangedEvent(
          leadId: 'test-1',
          oldStatus: LeadStatus.new_,
          newStatus: LeadStatus.called,
        ),
        LeadCreatedEvent(
          leadId: 'test-2',
          businessName: 'Business 2',
          industry: 'Tech',
          location: 'City',
        ),
      ]);
      
      final createdEvents = eventStore.getEventsByType<LeadCreatedEvent>();
      expect(createdEvents.length, 2);
      
      final statusEvents = eventStore.getEventsByType<LeadStatusChangedEvent>();
      expect(statusEvents.length, 1);
    });
    
    test('should create snapshot with statistics', () async {
      await eventStore.appendAll([
        LeadCreatedEvent(
          leadId: 'test-1',
          businessName: 'Business 1',
          industry: 'Tech',
          location: 'City',
        ),
        LeadStatusChangedEvent(
          leadId: 'test-1',
          oldStatus: LeadStatus.new_,
          newStatus: LeadStatus.converted,
        ),
        CallEndedEvent(
          leadId: 'test-1',
          duration: Duration(minutes: 5),
          outcome: 'Interested',
        ),
      ]);
      
      final snapshot = eventStore.createSnapshot();
      
      expect(snapshot['eventCount'], 3);
      expect(snapshot['leadStats']['created'], 1);
      expect(snapshot['leadStats']['conversions'], 1);
      expect(snapshot['activityStats']['calls'], 1);
    });
  });
  
  group('EventReplay Tests', () {
    late EventReplayService replayService;
    late EventStore eventStore;
    late EventBus eventBus;
    
    setUp(() async {
      eventStore = EventStore();
      eventBus = EventBus();
      replayService = EventReplayService();
      await eventStore.init();
    });
    
    tearDown(() {
      replayService.dispose();
      eventBus.dispose();
    });
    
    test('should replay all events', () async {
      // Store some events
      await eventStore.appendAll([
        LeadCreatedEvent(
          leadId: 'test-1',
          businessName: 'Business 1',
          industry: 'Tech',
          location: 'City',
        ),
        LeadStatusChangedEvent(
          leadId: 'test-1',
          oldStatus: LeadStatus.new_,
          newStatus: LeadStatus.called,
        ),
      ]);
      
      int replayedCount = 0;
      final subscription = eventBus.globalEventStream.listen((_) {
        replayedCount++;
      });
      
      final result = await replayService.replayAll(
        delay: Duration(milliseconds: 1),
      );
      
      expect(result.success, true);
      expect(result.eventsReplayed, 2);
      expect(replayedCount, 2);
      
      subscription.cancel();
    });
    
    test('should perform dry run without firing events', () async {
      await eventStore.appendAll([
        LeadCreatedEvent(
          leadId: 'test-1',
          businessName: 'Business',
          industry: 'Tech',
          location: 'City',
        ),
        LeadCreatedEvent(
          leadId: 'test-2',
          businessName: 'Business 2',
          industry: 'Tech',
          location: 'City',
        ),
      ]);
      
      final result = await replayService.dryRun();
      
      expect(result.success, true);
      expect(result.isDryRun, true);
      expect(result.eventsReplayed, 2);
      expect(result.metadata?['eventTypes']['LeadCreatedEvent'], 2);
    });
  });
  
  group('Event Handlers Tests', () {
    late AnalyticsHandler analyticsHandler;
    late EventBus eventBus;
    
    setUp(() {
      eventBus = EventBus();
      analyticsHandler = AnalyticsHandler();
      analyticsHandler.startListening();
    });
    
    tearDown(() {
      analyticsHandler.stopListening();
      eventBus.dispose();
    });
    
    test('should track event statistics', () async {
      eventBus.fire(LeadCreatedEvent(
        leadId: 'test-1',
        businessName: 'Business',
        industry: 'Tech',
        location: 'City',
      ));
      
      eventBus.fire(LeadCreatedEvent(
        leadId: 'test-2',
        businessName: 'Business 2',
        industry: 'Tech',
        location: 'City',
      ));
      
      await Future.delayed(Duration(milliseconds: 10));
      
      final stats = analyticsHandler.getStatistics();
      expect(stats['eventCounts']['LeadCreatedEvent'], 2);
    });
  });
}