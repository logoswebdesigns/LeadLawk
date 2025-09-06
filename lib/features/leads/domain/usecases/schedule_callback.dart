// Schedule Callback Use Case
// Pattern: Use Case Pattern (Clean Architecture)
// SOLID: Single Responsibility - manages callback scheduling
library;

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/lead.dart';
import '../entities/lead_timeline_entry.dart';

class ScheduleCallback {
  /// Calculate optimal callback time based on business hours
  DateTime calculateCallbackTime({
    DateTime? preferredDate,
    TimeOfDay? preferredTime,
    bool respectBusinessHours = true,
  }) {
    final now = DateTime.now();
    var targetDate = preferredDate ?? now.add(const Duration(days: 1));
    
    if (preferredTime != null) {
      targetDate = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        preferredTime.hour,
        preferredTime.minute,
      );
    }
    
    if (respectBusinessHours) {
      // Adjust to business hours (9 AM - 5 PM)
      if (targetDate.hour < 9) {
        targetDate = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          9,
          0,
        );
      } else if (targetDate.hour >= 17) {
        // Move to next business day at 9 AM
        targetDate = _nextBusinessDay(targetDate);
      }
      
      // Skip weekends
      if (targetDate.weekday == DateTime.saturday) {
        targetDate = targetDate.add(const Duration(days: 2));
      } else if (targetDate.weekday == DateTime.sunday) {
        targetDate = targetDate.add(const Duration(days: 1));
      }
    }
    
    return targetDate;
  }
  
  /// Get next business day at 9 AM
  DateTime _nextBusinessDay(DateTime date) {
    var next = date.add(const Duration(days: 1));
    next = DateTime(next.year, next.month, next.day, 9, 0);
    
    // Skip weekends
    while (next.weekday == DateTime.saturday || 
           next.weekday == DateTime.sunday) {
      next = next.add(const Duration(days: 1));
    }
    
    return next;
  }
  
  /// Generate callback reminder text
  String generateReminderText(Lead lead, DateTime callbackTime) {
    final timeStr = _formatTime(callbackTime);
    final dateStr = _formatDate(callbackTime);
    
    return 'Callback scheduled with ${lead.businessName} on $dateStr at $timeStr';
  }
  
  /// Create timeline entry for scheduled callback
  LeadTimelineEntry createTimelineEntry({
    required String leadId,
    required DateTime callbackTime,
    String? notes,
  }) {
    return LeadTimelineEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      leadId: leadId,
      type: TimelineEntryType.followUp,
      title: 'Callback Scheduled',
      description: notes ?? 'Callback scheduled',
      createdAt: DateTime.now(),
      followUpDate: callbackTime,
      metadata: {
        'scheduledFor': callbackTime.toIso8601String(),
      },
    );
  }
  
  /// Check if callback time is valid
  Either<Failure, DateTime> validateCallbackTime(DateTime proposedTime) {
    final now = DateTime.now();
    
    if (proposedTime.isBefore(now)) {
      return const Left(ValidationFailure('Cannot schedule callback in the past'));
    }
    
    // Warn if scheduling too far in future (>30 days)
    if (proposedTime.isAfter(now.add(const Duration(days: 30)))) {
      return const Left(ValidationFailure('Callback date too far in future'));
    }
    
    return Right(proposedTime);
  }
  
  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
  }
  
  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class TimeOfDay {
  final int hour;
  final int minute;
  
  TimeOfDay({required this.hour, required this.minute});
}