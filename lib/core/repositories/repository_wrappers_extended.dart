import 'package:dartz/dartz.dart';
import '../error/failures.dart';
import '../../features/leads/domain/entities/call_log.dart';
import '../../features/leads/domain/entities/lead_timeline_entry.dart';
import '../../features/leads/domain/repositories/call_log_repository.dart';
import '../../features/leads/domain/repositories/lead_timeline_repository.dart';
import 'base_repository.dart';

/// Wrapper for CallLogRepository
class CallLogRepositoryWrapper implements BaseRepository<CallLog> {
  final CallLogRepository _repository;

  CallLogRepositoryWrapper(this._repository);

  @override
  Future<Either<Failure, List<CallLog>>> getAll({Map<String, dynamic>? filters}) =>
      _repository.getAll(filters: filters);

  @override
  Future<Either<Failure, CallLog>> getById(String id) => _repository.getById(id);

  @override
  Future<Either<Failure, CallLog>> create(CallLog entity) => _repository.create(entity);

  @override
  Future<Either<Failure, CallLog>> update(CallLog entity) => _repository.update(entity);

  @override
  Future<Either<Failure, void>> delete(String id) => _repository.delete(id);

  @override
  Future<Either<Failure, void>> deleteMany(List<String> ids) => _repository.deleteMany(ids);

  @override
  Future<Either<Failure, bool>> exists(String id) => _repository.exists(id);

  @override
  Future<Either<Failure, int>> count({Map<String, dynamic>? filters}) =>
      _repository.count(filters: filters);

  @override
  Future<Either<Failure, void>> clearCache() => _repository.clearCache();

  @override
  Future<Either<Failure, void>> refresh() => _repository.refresh();
}

/// Enhanced CallLogRepository
class EnhancedCallLogRepository implements CallLogRepository {
  final BaseRepository<CallLog> _enhanced;
  final CallLogRepository _original;

  EnhancedCallLogRepository(this._enhanced, this._original);

  @override
  Future<Either<Failure, List<CallLog>>> getAll({Map<String, dynamic>? filters}) =>
      _enhanced.getAll(filters: filters);

  @override
  Future<Either<Failure, CallLog>> getById(String id) => _enhanced.getById(id);

  @override
  Future<Either<Failure, CallLog>> create(CallLog entity) => _enhanced.create(entity);

  @override
  Future<Either<Failure, CallLog>> update(CallLog entity) => _enhanced.update(entity);

  @override
  Future<Either<Failure, void>> delete(String id) => _enhanced.delete(id);

  @override
  Future<Either<Failure, void>> deleteMany(List<String> ids) => _enhanced.deleteMany(ids);

  @override
  Future<Either<Failure, bool>> exists(String id) => _enhanced.exists(id);

  @override
  Future<Either<Failure, int>> count({Map<String, dynamic>? filters}) =>
      _enhanced.count(filters: filters);

  @override
  Future<Either<Failure, void>> clearCache() => _enhanced.clearCache();

  @override
  Future<Either<Failure, void>> refresh() => _enhanced.refresh();

  // Delegate specialized methods
  @override
  Future<Either<Failure, List<CallLog>>> getCallLogsForLead(String leadId) =>
      _original.getCallLogsForLead(leadId);

  @override
  Future<Either<Failure, List<CallLog>>> getRecentCallLogs({
    int limit = 50,
    DateTime? since,
  }) => _original.getRecentCallLogs(limit: limit, since: since);

  @override
  Future<Either<Failure, List<CallLog>>> getCallLogsByOutcome(CallOutcome outcome) =>
      _original.getCallLogsByOutcome(outcome);

  @override
  Future<Either<Failure, Map<String, dynamic>>> getCallStats({
    DateTime? startDate,
    DateTime? endDate,
    String? leadId,
  }) => _original.getCallStats(
        startDate: startDate,
        endDate: endDate,
        leadId: leadId,
      );

  @override
  Future<Either<Failure, Duration>> getTotalCallDuration({
    DateTime? startDate,
    DateTime? endDate,
    String? leadId,
  }) => _original.getTotalCallDuration(
        startDate: startDate,
        endDate: endDate,
        leadId: leadId,
      );

  @override
  Future<Either<Failure, CallLog>> startCall(String leadId, String phoneNumber) =>
      _original.startCall(leadId, phoneNumber);

  @override
  Future<Either<Failure, CallLog>> endCall(String callId, CallOutcome outcome, {
    String? notes,
    String? recordingUrl,
  }) => _original.endCall(
        callId,
        outcome,
        notes: notes,
        recordingUrl: recordingUrl,
      );
}

/// Wrapper for LeadTimelineRepository
class TimelineRepositoryWrapper implements BaseRepository<LeadTimelineEntry> {
  final LeadTimelineRepository _repository;

  TimelineRepositoryWrapper(this._repository);

  @override
  Future<Either<Failure, List<LeadTimelineEntry>>> getAll({Map<String, dynamic>? filters}) =>
      _repository.getAll(filters: filters);

  @override
  Future<Either<Failure, LeadTimelineEntry>> getById(String id) => _repository.getById(id);

  @override
  Future<Either<Failure, LeadTimelineEntry>> create(LeadTimelineEntry entity) =>
      _repository.create(entity);

  @override
  Future<Either<Failure, LeadTimelineEntry>> update(LeadTimelineEntry entity) =>
      _repository.update(entity);

  @override
  Future<Either<Failure, void>> delete(String id) => _repository.delete(id);

  @override
  Future<Either<Failure, void>> deleteMany(List<String> ids) => _repository.deleteMany(ids);

  @override
  Future<Either<Failure, bool>> exists(String id) => _repository.exists(id);

  @override
  Future<Either<Failure, int>> count({Map<String, dynamic>? filters}) =>
      _repository.count(filters: filters);

  @override
  Future<Either<Failure, void>> clearCache() => _repository.clearCache();

  @override
  Future<Either<Failure, void>> refresh() => _repository.refresh();
}

/// Enhanced LeadTimelineRepository
class EnhancedTimelineRepository implements LeadTimelineRepository {
  final BaseRepository<LeadTimelineEntry> _enhanced;
  final LeadTimelineRepository _original;

  EnhancedTimelineRepository(this._enhanced, this._original);

  @override
  Future<Either<Failure, List<LeadTimelineEntry>>> getAll({Map<String, dynamic>? filters}) =>
      _enhanced.getAll(filters: filters);

  @override
  Future<Either<Failure, LeadTimelineEntry>> getById(String id) => _enhanced.getById(id);

  @override
  Future<Either<Failure, LeadTimelineEntry>> create(LeadTimelineEntry entity) =>
      _enhanced.create(entity);

  @override
  Future<Either<Failure, LeadTimelineEntry>> update(LeadTimelineEntry entity) =>
      _enhanced.update(entity);

  @override
  Future<Either<Failure, void>> delete(String id) => _enhanced.delete(id);

  @override
  Future<Either<Failure, void>> deleteMany(List<String> ids) => _enhanced.deleteMany(ids);

  @override
  Future<Either<Failure, bool>> exists(String id) => _enhanced.exists(id);

  @override
  Future<Either<Failure, int>> count({Map<String, dynamic>? filters}) =>
      _enhanced.count(filters: filters);

  @override
  Future<Either<Failure, void>> clearCache() => _enhanced.clearCache();

  @override
  Future<Either<Failure, void>> refresh() => _enhanced.refresh();

  // Delegate specialized methods
  @override
  Future<Either<Failure, List<LeadTimelineEntry>>> getTimelineForLead(
    String leadId, {
    int? limit,
    DateTime? since,
  }) => _original.getTimelineForLead(leadId, limit: limit, since: since);

  @override
  Future<Either<Failure, List<LeadTimelineEntry>>> getTimelineByType(
    String entryType, {
    String? leadId,
    int? limit,
  }) => _original.getTimelineByType(entryType, leadId: leadId, limit: limit);

  @override
  Future<Either<Failure, List<LeadTimelineEntry>>> getPendingFollowUps({
    DateTime? dueDate,
    bool overdue = false,
  }) => _original.getPendingFollowUps(dueDate: dueDate, overdue: overdue);

  @override
  Future<Either<Failure, LeadTimelineEntry>> markAsCompleted(
    String entryId, {
    String? completedBy,
    DateTime? completedAt,
  }) => _original.markAsCompleted(
        entryId,
        completedBy: completedBy,
        completedAt: completedAt,
      );

  @override
  Future<Either<Failure, Map<String, dynamic>>> getTimelineStats({
    DateTime? startDate,
    DateTime? endDate,
    String? leadId,
  }) => _original.getTimelineStats(
        startDate: startDate,
        endDate: endDate,
        leadId: leadId,
      );

  @override
  Future<Either<Failure, List<LeadTimelineEntry>>> createBulk(
    List<LeadTimelineEntry> entries,
  ) => _original.createBulk(entries);

  @override
  Future<Either<Failure, List<LeadTimelineEntry>>> getRecentActivity({
    int limit = 50,
    List<String>? entryTypes,
  }) => _original.getRecentActivity(limit: limit, entryTypes: entryTypes);
}