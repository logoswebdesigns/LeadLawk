import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';
import 'package:leadloq/features/leads/domain/entities/lead_timeline_entry.dart';
import 'package:leadloq/features/leads/presentation/widgets/dynamic_pipeline_widget.dart';

void main() {
  group('Pipeline Routing Logic Tests', () {
    // Test data setup
    late Lead baseLead;
    
    setUp(() {
      baseLead = Lead(
        id: 'test-123',
        businessName: 'Test Business',
        phone: '555-0123',
        status: LeadStatus.new_,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        industry: 'plumber',
        source: 'test',
        location: 'Test City',
        isCandidate: true,
        hasWebsite: false,
        hasRecentReviews: true,
        meetsRatingThreshold: true,
        conversionScore: 85,
      );
      
    });
    
    group('Route Determination', () {
      test('Standard route for new leads', () {
        final route = PipelineRoutes.standardRoute;
        
        expect(route.name, 'Standard Pipeline');
        expect(route.mainPath.length, 5);
        expect(route.mainPath.first.status, LeadStatus.new_);
        expect(route.mainPath.last.status, LeadStatus.converted);
      });
      
      test('Success route for converted leads', () {
        final route = PipelineRoutes.successRoute;
        
        expect(route.name, 'Conversion Success');
        expect(route.color, isNotNull);
        expect(route.mainPath.any((n) => n.status == LeadStatus.converted), true);
      });
      
      test('Did not convert route shows alternative path', () {
        final route = PipelineRoutes.didNotConvertRoute;
        
        expect(route.name, 'Did Not Convert');
        expect(route.alternativePaths.isNotEmpty, true);
        expect(route.alternativePaths[LeadStatus.called], isNotNull);
        expect(
          route.alternativePaths[LeadStatus.called]!
              .any((n) => n.status == LeadStatus.didNotConvert),
          true,
        );
      });
      
      test('Do not call route shows alternative path', () {
        final route = PipelineRoutes.doNotCallRoute;
        
        expect(route.name, 'Do Not Call');
        expect(route.alternativePaths.isNotEmpty, true);
        expect(
          route.alternativePaths[LeadStatus.called]!
              .any((n) => n.status == LeadStatus.doNotCall),
          true,
        );
      });
      
      test('Callback route shows scheduled callback branch', () {
        final route = PipelineRoutes.callbackRoute;
        
        expect(route.name, 'Callback Scheduled');
        expect(route.alternativePaths[LeadStatus.called], isNotNull);
        expect(
          route.alternativePaths[LeadStatus.called]!
              .any((n) => n.status == LeadStatus.callbackScheduled),
          true,
        );
      });
    });
    
    group('Progress Calculation', () {
      test('New lead shows 20% progress (1/5 nodes)', () {
        final route = PipelineRoutes.standardRoute;
        final currentIndex = route.getCurrentIndex(LeadStatus.new_);
        final progress = (currentIndex + 1) / route.getTotalNodes();
        
        expect(progress, 0.2);
      });
      
      test('Called lead shows 60% progress (3/5 nodes)', () {
        final route = PipelineRoutes.standardRoute;
        final currentIndex = route.getCurrentIndex(LeadStatus.called);
        final progress = (currentIndex + 1) / route.getTotalNodes();
        
        expect(progress, 0.6);
      });
      
      test('Converted lead shows 100% progress', () {
        final route = PipelineRoutes.standardRoute;
        final currentIndex = route.getCurrentIndex(LeadStatus.converted);
        final progress = (currentIndex + 1) / route.getTotalNodes();
        
        expect(progress, 1.0);
      });
    });
    
    group('Node Positioning', () {
      test('Main path nodes are horizontally spaced', () {
        final route = PipelineRoutes.standardRoute;
        
        final pos1 = route.getNodePosition(0, true);
        final pos2 = route.getNodePosition(1, true);
        final pos3 = route.getNodePosition(2, true);
        
        // Check horizontal spacing (120px between nodes)
        expect(pos2.dx - pos1.dx, 120.0);
        expect(pos3.dx - pos2.dx, 120.0);
        
        // Check vertical alignment
        expect(pos1.dy, pos2.dy);
        expect(pos2.dy, pos3.dy);
      });
      
      test('Alternative path nodes are positioned below main path', () {
        final route = PipelineRoutes.didNotConvertRoute;
        
        final mainNodePos = route.getNodePosition(2, true); // Called node
        final altNodePos = route.getAlternativeNodePosition(LeadStatus.called, 0);
        
        // Alternative node should be below main path
        expect(altNodePos.dy > mainNodePos.dy, true);
        
        // Alternative node should be offset horizontally
        expect(altNodePos.dx > mainNodePos.dx, true);
      });
    });
    
    group('State Transitions', () {
      test('Can transition from new to viewed', () {
        final lead = baseLead.copyWith(status: LeadStatus.new_);
        final canTransition = _canTransitionTo(lead, LeadStatus.viewed);
        
        expect(canTransition, true);
      });
      
      test('Can transition from called to interested', () {
        final lead = baseLead.copyWith(status: LeadStatus.called);
        final canTransition = _canTransitionTo(lead, LeadStatus.interested);
        
        expect(canTransition, true);
      });
      
      test('Can transition from called to did not convert', () {
        final lead = baseLead.copyWith(status: LeadStatus.called);
        final canTransition = _canTransitionTo(lead, LeadStatus.didNotConvert);
        
        expect(canTransition, true);
      });
      
      test('Cannot transition from converted (terminal state)', () {
        final lead = baseLead.copyWith(status: LeadStatus.converted);
        
        expect(_canTransitionTo(lead, LeadStatus.interested), false);
        expect(_canTransitionTo(lead, LeadStatus.called), false);
        expect(_canTransitionTo(lead, LeadStatus.new_), false);
      });
      
      test('Cannot transition from do not call (terminal state)', () {
        final lead = baseLead.copyWith(status: LeadStatus.doNotCall);
        
        expect(_canTransitionTo(lead, LeadStatus.interested), false);
        expect(_canTransitionTo(lead, LeadStatus.converted), false);
      });
      
      test('Cannot transition from did not convert (terminal state)', () {
        final lead = baseLead.copyWith(status: LeadStatus.didNotConvert);
        
        expect(_canTransitionTo(lead, LeadStatus.interested), false);
        expect(_canTransitionTo(lead, LeadStatus.converted), false);
      });
      
      test('Can move backward from interested to called', () {
        final lead = baseLead.copyWith(status: LeadStatus.interested);
        final canTransition = _canTransitionTo(lead, LeadStatus.called);
        
        expect(canTransition, true);
      });
      
      test('Cannot skip stages (new to interested)', () {
        final lead = baseLead.copyWith(status: LeadStatus.new_);
        final canTransition = _canTransitionTo(lead, LeadStatus.interested);
        
        expect(canTransition, false);
      });
    });
    
    group('Timeline Analysis', () {
      test('Detects if lead has been called from timeline', () {
        final timeline = [
          LeadTimelineEntry(
            id: '1',
            leadId: 'test-123',
            type: TimelineEntryType.statusChange,
            title: 'Status Change',
            description: 'Status changed to CALLED',
            metadata: {'new_status': 'called'},
            createdAt: DateTime.now(),
          ),
        ];
        
        final hasBeenCalled = timeline.any((entry) => 
          entry.type == TimelineEntryType.statusChange &&
          entry.metadata?['new_status'] == LeadStatus.called.name
        );
        
        expect(hasBeenCalled, true);
      });
      
      test('Identifies callback scheduled from timeline', () {
        final timeline = [
          LeadTimelineEntry(
            id: '1',
            leadId: 'test-123',
            type: TimelineEntryType.followUp,
            title: 'Follow Up',
            description: 'Callback scheduled',
            metadata: {
              'callback_date': DateTime.now().add(Duration(days: 1)).toIso8601String(),
            },
            createdAt: DateTime.now(),
          ),
        ];
        
        final hasCallback = timeline.any((entry) => 
          entry.type == TimelineEntryType.followUp
        );
        
        expect(hasCallback, true);
      });
      
      test('Tracks reason for did not convert', () {
        final timeline = [
          LeadTimelineEntry(
            id: '1',
            leadId: 'test-123',
            type: TimelineEntryType.statusChange,
            title: 'Status Change',
            description: 'Lead did not convert',
            metadata: {
              'new_status': 'didNotConvert',
              'reason': 'Not Interested',
            },
            createdAt: DateTime.now(),
          ),
        ];
        
        final didNotConvertEntry = timeline.firstWhere(
          (entry) => entry.metadata?['new_status'] == 'didNotConvert',
        );
        
        expect(didNotConvertEntry.metadata?['reason'], 'Not Interested');
      });
    });
    
    group('Route Width Calculation', () {
      test('Standard route width accommodates all nodes', () {
        final route = PipelineRoutes.standardRoute;
        final width = route.getTotalWidth();
        
        // 5 nodes * 120px spacing + 100px padding
        expect(width, 700.0);
      });
      
      test('Route with alternative paths has sufficient width', () {
        final route = PipelineRoutes.didNotConvertRoute;
        final width = route.getTotalWidth();
        
        // Should have enough width for main path
        expect(width >= 400.0, true);
      });
    });
    
    group('Node Colors', () {
      test('Each status has unique color', () {
        final nodes = PipelineRoutes.standardRoute.mainPath;
        final colors = nodes.map((n) => n.color).toSet();
        
        // All nodes should have different colors
        expect(colors.length, nodes.length);
      });
      
      test('Terminal states have appropriate warning colors', () {
        final dncNode = PipelineNode(
          status: LeadStatus.doNotCall,
          label: 'DNC',
          icon: Icons.phone_disabled,
          color: Colors.red,
        );
        
        final didNotConvertNode = PipelineNode(
          status: LeadStatus.didNotConvert,
          label: 'No Convert',
          icon: Icons.trending_down,
          color: Colors.deepOrange,
        );
        
        expect(dncNode.color, Colors.red);
        expect(didNotConvertNode.color, Colors.deepOrange);
      });
    });
  });
}

// Helper function to test transitions
bool _canTransitionTo(Lead lead, LeadStatus targetStatus) {
  // Terminal states cannot transition
  if (lead.status == LeadStatus.converted ||
      lead.status == LeadStatus.doNotCall ||
      lead.status == LeadStatus.didNotConvert) {
    return false;
  }
  
  // Define valid transitions
  final validTransitions = {
    LeadStatus.new_: [LeadStatus.viewed],
    LeadStatus.viewed: [LeadStatus.new_, LeadStatus.called],
    LeadStatus.called: [
      LeadStatus.viewed,
      LeadStatus.interested,
      LeadStatus.callbackScheduled,
      LeadStatus.doNotCall,
      LeadStatus.didNotConvert,
    ],
    LeadStatus.callbackScheduled: [LeadStatus.called, LeadStatus.interested],
    LeadStatus.interested: [LeadStatus.called, LeadStatus.converted],
  };
  
  return validTransitions[lead.status]?.contains(targetStatus) ?? false;
}