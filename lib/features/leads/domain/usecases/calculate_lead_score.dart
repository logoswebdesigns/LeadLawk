/// Calculate Lead Score Use Case
/// Pattern: Strategy Pattern for scoring algorithms
/// SOLID: Open/Closed - new scoring strategies without modification
library;

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/lead.dart';

abstract class ScoringStrategy {
  int calculate(Lead lead);
  String get name;
}

class StandardScoringStrategy implements ScoringStrategy {
  @override
  String get name => 'Standard';
  
  @override
  int calculate(Lead lead) {
    int score = 0;
    
    // Website presence (30 points)
    if (lead.hasWebsite) {
      score += 20;
      // PageSpeed scores
      if (lead.pagespeedMobileScore != null) {
        if (lead.pagespeedMobileScore! < 50) {
          score += 10; // Poor website = opportunity
        } else if (lead.pagespeedMobileScore! < 70) {
          score += 5;
        }
      }
    } else {
      score += 30; // No website = high opportunity
    }
    
    // Business metrics (30 points)
    if (lead.rating != null) {
      if (lead.rating! >= 4.5) {
        score += 20; // High rating = established business
      } else if (lead.rating! >= 4.0) {
        score += 15;
      } else if (lead.rating! >= 3.5) {
        score += 10;
      } else {
        score += 5; // Low rating = needs help
      }
    }
    
    if (lead.reviewCount != null) {
      if (lead.reviewCount! >= 100) {
        score += 10; // High engagement
      } else if (lead.reviewCount! >= 50) {
        score += 7;
      } else if (lead.reviewCount! >= 20) {
        score += 5;
      } else {
        score += 3;
      }
    }
    
    // Contact information (20 points)
    if (lead.phone.isNotEmpty) score += 20;
    
    // Engagement status (20 points)
    switch (lead.status) {
      case LeadStatus.new_:
        score += 20;
      case LeadStatus.viewed:
        score += 15;
      case LeadStatus.called:
        score += 10;
      case LeadStatus.interested:
        score += 25; // Boost interested leads
      case LeadStatus.callbackScheduled:
        score += 20;
      case LeadStatus.converted:
        score += 0; // Already converted
      case LeadStatus.didNotConvert:
        score -= 10; // Decrease priority
      case LeadStatus.doNotCall:
        score = 0; // No score for DNC
    }
    
    return score.clamp(0, 100);
  }
}

class OpportunityBasedScoringStrategy implements ScoringStrategy {
  @override
  String get name => 'Opportunity Based';
  
  @override
  int calculate(Lead lead) {
    int score = 0;
    
    // Prioritize businesses with problems
    if (!lead.hasWebsite) {
      score += 40; // Highest opportunity
    } else if (lead.pagespeedMobileScore != null && lead.pagespeedMobileScore! < 50) {
      score += 35; // Poor website performance
    }
    
    // Medium-sized businesses are ideal
    if (lead.reviewCount != null) {
      if (lead.reviewCount! >= 20 && lead.reviewCount! <= 100) {
        score += 30; // Sweet spot
      } else if (lead.reviewCount! < 20) {
        score += 20; // Small business
      } else {
        score += 10; // Large business
      }
    }
    
    // Lower ratings = more need for help
    if (lead.rating != null) {
      if (lead.rating! < 3.5) {
        score += 20;
      } else if (lead.rating! < 4.0) {
        score += 15;
      } else if (lead.rating! < 4.5) {
        score += 10;
      } else {
        score += 5;
      }
    }
    
    // Contact availability
    if (lead.phone.isNotEmpty) score += 10;
    
    return score.clamp(0, 100);
  }
}

class CalculateLeadScore {
  final Map<String, ScoringStrategy> _strategies = {
    'standard': StandardScoringStrategy(),
    'opportunity': OpportunityBasedScoringStrategy(),
  };
  
  /// Calculate lead score using specified strategy
  Either<Failure, int> calculate(Lead lead, {String strategy = 'standard'}) {
    final scorer = _strategies[strategy];
    
    if (scorer == null) {
      return Left(ValidationFailure('Unknown scoring strategy: $strategy'));
    }
    
    try {
      final score = scorer.calculate(lead);
      return Right(score);
    } catch (e) {
      return Left(ProcessingFailure('Failed to calculate score: $e'));
    }
  }
  
  /// Get lead quality tier based on score
  String getQualityTier(int score) {
    if (score >= 80) return 'Hot';
    if (score >= 60) return 'Warm';
    if (score >= 40) return 'Cool';
    if (score >= 20) return 'Cold';
    return 'Frozen';
  }
  
  /// Get recommended action based on score
  String getRecommendedAction(Lead lead, int score) {
    if (lead.status == LeadStatus.doNotCall) {
      return 'Do not contact - marked as DNC';
    }
    
    if (score >= 80) {
      return 'Call immediately - high priority lead';
    } else if (score >= 60) {
      if (lead.status == LeadStatus.new_) {
        return 'Call within 24 hours';
      } else if (lead.status == LeadStatus.viewed) {
        return 'Follow up call recommended';
      }
    } else if (score >= 40) {
      return 'Add to nurture campaign';
    }
    
    return 'Low priority - review later';
  }
  
  /// Register custom scoring strategy
  void registerStrategy(String name, ScoringStrategy strategy) {
    _strategies[name] = strategy;
  }
}