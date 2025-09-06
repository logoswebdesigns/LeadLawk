import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/repositories/base_repository.dart';
import '../entities/lead_timeline_entry.dart';

abstract class LeadTimelineRepository implements BaseRepository<LeadTimelineEntry> {
  /// Get timeline entries for a specific lead
  Future<Either<Failure, List<LeadTimelineEntry>>> getTimelineForLead(
    String leadId, {
    int? limit,
    DateTime? since,
  });
  
  /// Get timeline entries by type
  Future<Either<Failure, List<LeadTimelineEntry>>> getTimelineByType(
    String entryType, {
    String? leadId,
    int? limit,
  });
  
  /// Get pending follow-ups
  Future<Either<Failure, List<LeadTimelineEntry>>> getPendingFollowUps({
    DateTime? dueDate,
    bool overdue = false,
  });
  
  /// Mark timeline entry as completed
  Future<Either<Failure, LeadTimelineEntry>> markAsCompleted(
    String entryId, {
    String? completedBy,
    DateTime? completedAt,
  });
  
  /// Get timeline statistics
  Future<Either<Failure, Map<String, dynamic>>> getTimelineStats({
    DateTime? startDate,
    DateTime? endDate,
    String? leadId,
  });
  
  /// Bulk create timeline entries
  Future<Either<Failure, List<LeadTimelineEntry>>> createBulk(
    List<LeadTimelineEntry> entries,
  );
  
  /// Get recent activity across all leads
  Future<Either<Failure, List<LeadTimelineEntry>>> getRecentActivity({
    int limit = 50,
    List<String>? entryTypes,
  });
}