// Manage Lead Pipeline Use Case
// Pattern: State Machine Pattern for lead progression
// SOLID: Open/Closed - extend pipeline stages without modification
library;

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/lead.dart';

class ManageLeadPipeline {
  /// Valid status transitions
  static const Map<LeadStatus, List<LeadStatus>> _validTransitions = {
    LeadStatus.new_: [
      LeadStatus.viewed,
      LeadStatus.called,
      LeadStatus.doNotCall,
    ],
    LeadStatus.viewed: [
      LeadStatus.called,
      LeadStatus.interested,
      LeadStatus.didNotConvert,
      LeadStatus.doNotCall,
    ],
    LeadStatus.called: [
      LeadStatus.interested,
      LeadStatus.callbackScheduled,
      LeadStatus.didNotConvert,
      LeadStatus.doNotCall,
    ],
    LeadStatus.interested: [
      LeadStatus.callbackScheduled,
      LeadStatus.converted,
      LeadStatus.didNotConvert,
    ],
    LeadStatus.callbackScheduled: [
      LeadStatus.called,
      LeadStatus.interested,
      LeadStatus.converted,
      LeadStatus.didNotConvert,
    ],
    LeadStatus.converted: [],
    LeadStatus.didNotConvert: [
      LeadStatus.interested,
      LeadStatus.callbackScheduled,
    ],
    LeadStatus.doNotCall: [],
  };
  
  /// Check if status transition is valid
  bool canTransition(LeadStatus from, LeadStatus to) {
    final validNext = _validTransitions[from] ?? [];
    return validNext.contains(to);
  }
  
  /// Get available next statuses
  List<LeadStatus> getAvailableTransitions(LeadStatus currentStatus) {
    return _validTransitions[currentStatus] ?? [];
  }
  
  /// Calculate pipeline stage progress (0-100)
  int calculateProgress(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return 0;
      case LeadStatus.viewed:
        return 15;
      case LeadStatus.called:
        return 30;
      case LeadStatus.interested:
        return 60;
      case LeadStatus.callbackScheduled:
        return 75;
      case LeadStatus.converted:
        return 100;
      case LeadStatus.didNotConvert:
        return 0;
      case LeadStatus.doNotCall:
        return 0;
    }
  }
  
  /// Get stage color for visualization
  String getStageColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return '#9CA3AF'; // Gray
      case LeadStatus.viewed:
        return '#60A5FA'; // Light Blue
      case LeadStatus.called:
        return '#34D399'; // Green
      case LeadStatus.interested:
        return '#FBBF24'; // Yellow
      case LeadStatus.callbackScheduled:
        return '#F97316'; // Orange
      case LeadStatus.converted:
        return '#10B981'; // Emerald
      case LeadStatus.didNotConvert:
        return '#EF4444'; // Red
      case LeadStatus.doNotCall:
        return '#6B7280'; // Dark Gray
    }
  }
  
  /// Get recommended action for current stage
  String getStageAction(LeadStatus status) {
    switch (status) {
      case LeadStatus.new_:
        return 'Review lead details and mark as viewed';
      case LeadStatus.viewed:
        return 'Call the lead to qualify opportunity';
      case LeadStatus.called:
        return 'Follow up based on call outcome';
      case LeadStatus.interested:
        return 'Schedule callback or send proposal';
      case LeadStatus.callbackScheduled:
        return 'Prepare for scheduled callback';
      case LeadStatus.converted:
        return 'Complete onboarding process';
      case LeadStatus.didNotConvert:
        return 'Add to nurture campaign';
      case LeadStatus.doNotCall:
        return 'No action required';
    }
  }
  
  /// Validate status transition with reason
  Either<Failure, LeadStatus> validateTransition(
    LeadStatus from,
    LeadStatus to,
  ) {
    if (from == to) {
      return const Left(ValidationFailure('Status unchanged'));
    }
    
    if (!canTransition(from, to)) {
      final available = getAvailableTransitions(from);
      if (available.isEmpty) {
        return Left(ValidationFailure(
          'No transitions available from ${from.name}'
        ));
      }
      return Left(ValidationFailure(
        'Invalid transition from ${from.name} to ${to.name}'
      ));
    }
    
    return Right(to);
  }
  
  /// Get pipeline statistics
  Map<String, dynamic> getPipelineStats(List<Lead> leads) {
    final stats = <LeadStatus, int>{};
    
    for (final status in LeadStatus.values) {
      stats[status] = 0;
    }
    
    for (final lead in leads) {
      stats[lead.status] = (stats[lead.status] ?? 0) + 1;
    }
    
    final total = leads.length;
    final conversionRate = total > 0 
      ? (stats[LeadStatus.converted]! / total * 100).toStringAsFixed(1)
      : '0.0';
    
    return {
      'total': total,
      'byStatus': stats,
      'conversionRate': conversionRate,
      'inProgress': stats[LeadStatus.called]! + 
                    stats[LeadStatus.interested]! +
                    stats[LeadStatus.callbackScheduled]!,
    };
  }
}