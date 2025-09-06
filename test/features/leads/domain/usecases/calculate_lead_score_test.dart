import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/domain/usecases/calculate_lead_score.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';

void main() {
  late CalculateLeadScore calculateLeadScore;
  
  setUp(() {
    calculateLeadScore = CalculateLeadScore();
  });
  
  group('StandardScoringStrategy', () {
    test('should score lead without website highly', () {
      final lead = Lead(
        id: '1',
        businessName: 'Test Business',
        phone: '555-1234',
        industry: 'unknown',
        location: 'unknown',
        source: 'manual',
        hasWebsite: false,
        meetsRatingThreshold: false,
        hasRecentReviews: false,
        isCandidate: true,
        status: LeadStatus.new_,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now());
      
      final result = calculateLeadScore.calculate(lead);
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (score) {
          expect(score, greaterThanOrEqualTo(50));
        },
      );
    });
    
    test('should score lead with poor PageSpeed highly', () {
      final lead = Lead(
        id: '2',
        businessName: 'Test Business',
        phone: '555-1234',
        websiteUrl: 'https://example.com',
        pagespeedMobileScore: 35,
        industry: 'unknown',
        location: 'unknown',
        source: 'manual',
        hasWebsite: true,
        meetsRatingThreshold: false,
        hasRecentReviews: false,
        isCandidate: true,
        status: LeadStatus.new_,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now());
      
      final result = calculateLeadScore.calculate(lead);
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (score) {
          expect(score, greaterThanOrEqualTo(40));
        },
      );
    });
    
    test('should give zero score to DNC leads', () {
      final lead = Lead(
        id: '3',
        businessName: 'Test Business',
        phone: '555-1234',
        industry: 'unknown',
        location: 'unknown',
        source: 'manual',
        hasWebsite: true,
        meetsRatingThreshold: false,
        hasRecentReviews: false,
        isCandidate: true,
        status: LeadStatus.doNotCall,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now());
      
      final result = calculateLeadScore.calculate(lead);
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (score) {
          expect(score, equals(0));
        },
      );
    });
  });
  
  group('OpportunityBasedScoringStrategy', () {
    test('should prioritize businesses without websites', () {
      final lead = Lead(
        id: '4',
        businessName: 'No Website Business',
        phone: '555-1234',
        reviewCount: 50,
        rating: 4.5,
        industry: 'unknown',
        location: 'unknown',
        source: 'manual',
        hasWebsite: false,
        meetsRatingThreshold: false,
        hasRecentReviews: false,
        isCandidate: true,
        status: LeadStatus.new_,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now());
      
      final result = calculateLeadScore.calculate(
        lead, 
        strategy: 'opportunity'
      );
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (score) {
          expect(score, greaterThanOrEqualTo(60));
        },
      );
    });
  });
  
  group('Quality Tier', () {
    test('should return correct quality tiers', () {
      expect(calculateLeadScore.getQualityTier(85), equals('Hot'));
      expect(calculateLeadScore.getQualityTier(65), equals('Warm'));
      expect(calculateLeadScore.getQualityTier(45), equals('Cool'));
      expect(calculateLeadScore.getQualityTier(25), equals('Cold'));
      expect(calculateLeadScore.getQualityTier(10), equals('Frozen'));
    });
  });
  
  group('Recommended Actions', () {
    test('should recommend immediate call for high score', () {
      final lead = Lead(
        id: '5',
        businessName: 'Hot Lead',
        phone: '555-1234',
        industry: 'unknown',
        location: 'unknown',
        source: 'manual',
        hasWebsite: false,
        meetsRatingThreshold: false,
        hasRecentReviews: false,
        isCandidate: true,
        status: LeadStatus.new_,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now());
      
      final action = calculateLeadScore.getRecommendedAction(lead, 85);
      expect(action, contains('Call immediately'));
    });
    
    test('should respect DNC status', () {
      final lead = Lead(
        id: '6',
        businessName: 'DNC Lead',
        phone: '555-1234',
        industry: 'unknown',
        location: 'unknown',
        source: 'manual',
        hasWebsite: false,
        meetsRatingThreshold: false,
        hasRecentReviews: false,
        isCandidate: true,
        status: LeadStatus.doNotCall,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now());
      
      final action = calculateLeadScore.getRecommendedAction(lead, 90);
      expect(action, contains('Do not contact'));
    });
  });
}