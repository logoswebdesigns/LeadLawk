import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/domain/usecases/manage_lead_pipeline.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';

void main() {
  late ManageLeadPipeline manageLeadPipeline;
  
  setUp(() {
    manageLeadPipeline = ManageLeadPipeline();
  });
  
  group('Status Transitions', () {
    test('should allow valid transition from new to viewed', () {
      final canTransition = manageLeadPipeline.canTransition(
        LeadStatus.new_,
        LeadStatus.viewed,
      );
      
      expect(canTransition, isTrue);
    });
    
    test('should allow valid transition from called to interested', () {
      final canTransition = manageLeadPipeline.canTransition(
        LeadStatus.called,
        LeadStatus.interested,
      );
      
      expect(canTransition, isTrue);
    });
    
    test('should not allow invalid transition from new to converted', () {
      final canTransition = manageLeadPipeline.canTransition(
        LeadStatus.new_,
        LeadStatus.converted,
      );
      
      expect(canTransition, isFalse);
    });
    
    test('should not allow transitions from converted status', () {
      final transitions = manageLeadPipeline.getAvailableTransitions(
        LeadStatus.converted,
      );
      
      expect(transitions, isEmpty);
    });
    
    test('should not allow transitions from doNotCall status', () {
      final transitions = manageLeadPipeline.getAvailableTransitions(
        LeadStatus.doNotCall,
      );
      
      expect(transitions, isEmpty);
    });
  });
  
  group('Progress Calculation', () {
    test('should calculate correct progress for each status', () {
      expect(manageLeadPipeline.calculateProgress(LeadStatus.new_), equals(0));
      expect(manageLeadPipeline.calculateProgress(LeadStatus.viewed), equals(15));
      expect(manageLeadPipeline.calculateProgress(LeadStatus.called), equals(30));
      expect(manageLeadPipeline.calculateProgress(LeadStatus.interested), equals(60));
      expect(manageLeadPipeline.calculateProgress(LeadStatus.callbackScheduled), equals(75));
      expect(manageLeadPipeline.calculateProgress(LeadStatus.converted), equals(100));
      expect(manageLeadPipeline.calculateProgress(LeadStatus.didNotConvert), equals(0));
      expect(manageLeadPipeline.calculateProgress(LeadStatus.doNotCall), equals(0));
    });
  });
  
  group('Stage Colors', () {
    test('should return correct colors for each status', () {
      expect(manageLeadPipeline.getStageColor(LeadStatus.new_), equals('#9CA3AF'));
      expect(manageLeadPipeline.getStageColor(LeadStatus.converted), equals('#10B981'));
      expect(manageLeadPipeline.getStageColor(LeadStatus.didNotConvert), equals('#EF4444'));
    });
  });
  
  group('Stage Actions', () {
    test('should return appropriate action for new lead', () {
      final action = manageLeadPipeline.getStageAction(LeadStatus.new_);
      expect(action, contains('Review lead details'));
    });
    
    test('should return appropriate action for interested lead', () {
      final action = manageLeadPipeline.getStageAction(LeadStatus.interested);
      expect(action, contains('Schedule callback'));
    });
  });
  
  group('Transition Validation', () {
    test('should validate valid transition', () {
      final result = manageLeadPipeline.validateTransition(
        LeadStatus.new_,
        LeadStatus.viewed,
      );
      
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should not fail'),
        (status) {
          expect(status, equals(LeadStatus.viewed));
        },
      );
    });
    
    test('should reject invalid transition', () {
      final result = manageLeadPipeline.validateTransition(
        LeadStatus.new_,
        LeadStatus.converted,
      );
      
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure.message, contains('Invalid transition'));
        },
        (_) => fail('Should fail'),
      );
    });
    
    test('should reject same status transition', () {
      final result = manageLeadPipeline.validateTransition(
        LeadStatus.new_,
        LeadStatus.new_,
      );
      
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure.message, contains('Status unchanged'));
        },
        (_) => fail('Should fail'),
      );
    });
  });
  
  group('Pipeline Statistics', () {
    test('should calculate pipeline statistics correctly', () {
      final leads = [
        Lead(
          id: '1',
          businessName: 'Business 1',
          phone: '555-0001',
          status: LeadStatus.new_,
          industry: 'unknown',
          location: 'unknown',
          source: 'manual',
          hasWebsite: false,
          meetsRatingThreshold: false,
          hasRecentReviews: false,
          isCandidate: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now()),
        Lead(
          id: '2',
          businessName: 'Business 2',
          phone: '555-0002',
          status: LeadStatus.called,
          industry: 'unknown',
          location: 'unknown',
          source: 'manual',
          hasWebsite: false,
          meetsRatingThreshold: false,
          hasRecentReviews: false,
          isCandidate: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now()),
        Lead(
          id: '3',
          businessName: 'Business 3',
          phone: '555-0003',
          status: LeadStatus.interested,
          industry: 'unknown',
          location: 'unknown',
          source: 'manual',
          hasWebsite: false,
          meetsRatingThreshold: false,
          hasRecentReviews: false,
          isCandidate: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now()),
        Lead(
          id: '4',
          businessName: 'Business 4',
          phone: '555-0004',
          status: LeadStatus.converted,
          industry: 'unknown',
          location: 'unknown',
          source: 'manual',
          hasWebsite: false,
          meetsRatingThreshold: false,
          hasRecentReviews: false,
          isCandidate: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now()),
      ];
      
      final stats = manageLeadPipeline.getPipelineStats(leads);
      
      expect(stats['total'], equals(4));
      expect(stats['conversionRate'], equals('25.0'));
      expect(stats['inProgress'], equals(2)); // called + interested
      
      final byStatus = stats['byStatus'] as Map<LeadStatus, int>;
      expect(byStatus[LeadStatus.new_], equals(1));
      expect(byStatus[LeadStatus.called], equals(1));
      expect(byStatus[LeadStatus.interested], equals(1));
      expect(byStatus[LeadStatus.converted], equals(1));
    });
    
    test('should handle empty lead list', () {
      final stats = manageLeadPipeline.getPipelineStats([]);
      
      expect(stats['total'], equals(0));
      expect(stats['conversionRate'], equals('0.0'));
      expect(stats['inProgress'], equals(0));
    });
  });
}