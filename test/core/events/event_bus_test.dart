// Tests for event bus system.
// Pattern: Unit Testing - event system verification.

import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/core/events/event_bus.dart';
import 'package:leadloq/core/events/domain_events.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';

void main() {
  group('EventBus Tests', () {
    late EventBus eventBus;
    
    setUp(() {
      eventBus = EventBus();
    });
    
    tearDown(() {
      eventBus.clearHistory();
    });
    
    test('subscribers receive events', () async {
      var received = false;
      final event = LeadCreatedEvent(
        leadId: 'test-id',
        businessName: 'Test Business',
        industry: 'Tech',
        location: 'City',
      );
      
      final subscription = eventBus.on<LeadCreatedEvent>().listen((e) {
        received = true;
        expect(e.leadId, equals('test-id'));
      });
      
      eventBus.fire(event);
      await Future.delayed(Duration.zero); // Allow event propagation
      
      expect(received, isTrue);
      subscription.cancel();
    });
    
    test('multiple subscribers receive same event', () async {
      var count = 0;
      
      final sub1 = eventBus.on<LeadCreatedEvent>().listen((_) => count++);
      final sub2 = eventBus.on<LeadCreatedEvent>().listen((_) => count++);
      final sub3 = eventBus.on<LeadCreatedEvent>().listen((_) => count++);
      
      eventBus.fire(LeadCreatedEvent(
        leadId: 'test',
        businessName: 'Business',
        industry: 'Industry',
        location: 'Location',
      ));
      
      await Future.delayed(Duration.zero);
      
      expect(count, equals(3));
      
      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
    });
    
    test('type-specific subscriptions work', () async {
      var createdCount = 0;
      var statusCount = 0;
      
      final sub1 = eventBus.on<LeadCreatedEvent>().listen((_) => createdCount++);
      final sub2 = eventBus.on<LeadStatusChangedEvent>().listen((_) => statusCount++);
      
      eventBus.fire(LeadCreatedEvent(
        leadId: 'test',
        businessName: 'Business',
        industry: 'Industry',
        location: 'Location',
      ));
      
      eventBus.fire(LeadStatusChangedEvent(
        leadId: 'test',
        oldStatus: LeadStatus.new_,
        newStatus: LeadStatus.called,
      ));
      
      await Future.delayed(Duration.zero);
      
      expect(createdCount, equals(1));
      expect(statusCount, equals(1));
      
      sub1.cancel();
      sub2.cancel();
    });
    
    test('global event stream receives all events', () async {
      final events = <AppEvent>[];
      
      final subscription = eventBus.globalEventStream.listen(events.add);
      
      eventBus.fire(LeadCreatedEvent(
        leadId: 'test1',
        businessName: 'Business',
        industry: 'Industry',
        location: 'Location',
      ));
      
      eventBus.fire(LeadStatusChangedEvent(
        leadId: 'test2',
        oldStatus: LeadStatus.new_,
        newStatus: LeadStatus.called,
      ));
      
      await Future.delayed(Duration.zero);
      
      expect(events.length, equals(2));
      expect(events[0], isA<LeadCreatedEvent>());
      expect(events[1], isA<LeadStatusChangedEvent>());
      
      subscription.cancel();
    });
    
    test('event history is maintained', () {
      final event1 = LeadCreatedEvent(
        leadId: 'test1',
        businessName: 'Business1',
        industry: 'Industry',
        location: 'Location',
      );
      
      final event2 = LeadStatusChangedEvent(
        leadId: 'test1',
        oldStatus: LeadStatus.new_,
        newStatus: LeadStatus.called,
      );
      
      eventBus.fire(event1);
      eventBus.fire(event2);
      
      final history = eventBus.getHistory();
      
      expect(history.length, equals(2));
      expect(history[0], equals(event1));
      expect(history[1], equals(event2));
    });
    
    test('history can be filtered', () {
      eventBus.fire(LeadCreatedEvent(
        leadId: 'test1',
        businessName: 'Business1',
        industry: 'Industry',
        location: 'Location',
        userId: 'user1',
      ));
      
      eventBus.fire(LeadStatusChangedEvent(
        leadId: 'test1',
        oldStatus: LeadStatus.new_,
        newStatus: LeadStatus.called,
        userId: 'user2',
      ));
      
      eventBus.fire(LeadCreatedEvent(
        leadId: 'test2',
        businessName: 'Business2',
        industry: 'Industry',
        location: 'Location',
        userId: 'user1',
      ));
      
      // Filter by event type
      final createdEvents = eventBus.getHistory(
        eventType: 'LeadCreatedEvent',
      );
      expect(createdEvents.length, equals(2));
      
      // Filter by user
      final user1Events = eventBus.getHistory(userId: 'user1');
      expect(user1Events.length, equals(2));
      
      // Filter by both
      final filtered = eventBus.getHistory(
        eventType: 'LeadCreatedEvent',
        userId: 'user1',
      );
      expect(filtered.length, equals(2));
    });
    
    test('fireAsync waits for handlers', () async {
      var processed = false;
      
      eventBus.on<LeadCreatedEvent>().listen((event) async {
        await Future.delayed(Duration(milliseconds: 10));
        processed = true;
      });
      
      await eventBus.fireAsync(LeadCreatedEvent(
        leadId: 'test',
        businessName: 'Business',
        industry: 'Industry',
        location: 'Location',
      ));
      
      expect(processed, isTrue);
    });
    
    test('handles subscription cancellation', () async {
      var count = 0;
      
      final subscription = eventBus.on<LeadCreatedEvent>().listen((_) => count++);
      
      eventBus.fire(LeadCreatedEvent(
        leadId: 'test1',
        businessName: 'Business',
        industry: 'Industry',
        location: 'Location',
      ));
      
      await Future.delayed(Duration.zero);
      expect(count, equals(1));
      
      subscription.cancel();
      
      eventBus.fire(LeadCreatedEvent(
        leadId: 'test2',
        businessName: 'Business',
        industry: 'Industry',
        location: 'Location',
      ));
      
      await Future.delayed(Duration.zero);
      expect(count, equals(1)); // Should not increase
    });
  });
}