import 'package:dartz/dartz.dart';
import '../error/failures.dart';
import '../../features/leads/domain/entities/lead.dart';
import '../../features/leads/domain/entities/job.dart';
import '../../features/leads/domain/entities/lead_timeline_entry.dart';
import '../../features/leads/domain/repositories/leads_repository.dart';
import '../../features/leads/domain/repositories/job_repository.dart';
import '../../features/leads/domain/usecases/browser_automation_usecase.dart';
import 'base_repository.dart';

/// Wrapper to adapt LeadsRepository to BaseRepository
class LeadsRepositoryWrapper implements BaseRepository<Lead> {
  final LeadsRepository _repository;

  LeadsRepositoryWrapper(this._repository);

  @override
  Future<Either<Failure, List<Lead>>> getAll({Map<String, dynamic>? filters}) {
    return _repository.getLeads(
      status: filters?['status'],
      search: filters?['search'],
      candidatesOnly: filters?['candidatesOnly'],
    );
  }

  @override
  Future<Either<Failure, Lead>> getById(String id) => _repository.getLead(id);

  @override
  Future<Either<Failure, Lead>> create(Lead entity) async {
    return const Left(ValidationFailure('Lead creation not supported'));
  }

  @override
  Future<Either<Failure, Lead>> update(Lead entity) => _repository.updateLead(entity);

  @override
  Future<Either<Failure, void>> delete(String id) => _repository.deleteLead(id);

  @override
  Future<Either<Failure, void>> deleteMany(List<String> ids) => _repository.deleteLeads(ids);

  @override
  Future<Either<Failure, bool>> exists(String id) async {
    final result = await _repository.getLead(id);
    return Right(result.isRight());
  }

  @override
  Future<Either<Failure, int>> count({Map<String, dynamic>? filters}) async {
    final result = await getAll(filters: filters);
    return result.fold((l) => Left(l), (leads) => Right(leads.length));
  }

  @override
  Future<Either<Failure, void>> clearCache() async => const Right(null);

  @override
  Future<Either<Failure, void>> refresh() async => const Right(null);
}

/// Enhanced LeadsRepository that delegates to decorated BaseRepository
class EnhancedLeadsRepository implements LeadsRepository {
  final BaseRepository<Lead> _enhanced;
  final LeadsRepository _original;

  EnhancedLeadsRepository(this._enhanced, this._original);

  @override
  Future<Either<Failure, List<Lead>>> getLeads({
    String? status,
    String? search,
    bool? candidatesOnly,
  }) {
    final filters = <String, dynamic>{};
    if (status != null) filters['status'] = status;
    if (search != null) filters['search'] = search;
    if (candidatesOnly != null) filters['candidatesOnly'] = candidatesOnly;
    return _enhanced.getAll(filters: filters);
  }

  @override
  Future<Either<Failure, Lead>> getLead(String id) => _enhanced.getById(id);

  @override
  Future<Either<Failure, Lead>> updateLead(Lead lead, {bool? addToBlacklist, String? blacklistReason}) => 
      _original.updateLead(lead, addToBlacklist: addToBlacklist, blacklistReason: blacklistReason);

  @override
  Future<Either<Failure, void>> deleteLead(String id) => _enhanced.delete(id);

  @override
  Future<Either<Failure, void>> deleteLeads(List<String> ids) => _enhanced.deleteMany(ids);

  // Delegate specialized methods to original repository
  @override
  Future<Either<Failure, Lead>> updateTimelineEntry(String leadId, LeadTimelineEntry entry) =>
      _original.updateTimelineEntry(leadId, entry);

  @override
  Future<Either<Failure, void>> addTimelineEntry(String leadId, Map<String, dynamic> entryData) =>
      _original.addTimelineEntry(leadId, entryData);

  @override
  Future<Either<Failure, String>> startAutomation(BrowserAutomationParams params) =>
      _original.startAutomation(params);

  @override
  Stream<Job> watchJob(String jobId) => _original.watchJob(jobId);

  @override
  Future<Either<Failure, int>> deleteMockLeads() => _original.deleteMockLeads();

  @override
  Future<Either<Failure, Map<String, dynamic>>> recalculateConversionScores() =>
      _original.recalculateConversionScores();

  @override
  Future<Either<Failure, Map<DateTime, int>>> getCallStatistics() =>
      _original.getCallStatistics();
}

/// Wrapper for JobRepository
class JobRepositoryWrapper implements BaseRepository<Job> {
  final JobRepository _repository;

  JobRepositoryWrapper(this._repository);

  @override
  Future<Either<Failure, List<Job>>> getAll({Map<String, dynamic>? filters}) =>
      _repository.getAll(filters: filters);

  @override
  Future<Either<Failure, Job>> getById(String id) => _repository.getById(id);

  @override
  Future<Either<Failure, Job>> create(Job entity) => _repository.create(entity);

  @override
  Future<Either<Failure, Job>> update(Job entity) => _repository.update(entity);

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

/// Enhanced JobRepository
class EnhancedJobRepository implements JobRepository {
  final BaseRepository<Job> _enhanced;
  final JobRepository _original;

  EnhancedJobRepository(this._enhanced, this._original);

  @override
  Future<Either<Failure, List<Job>>> getAll({Map<String, dynamic>? filters}) =>
      _enhanced.getAll(filters: filters);

  @override
  Future<Either<Failure, Job>> getById(String id) => _enhanced.getById(id);

  @override
  Future<Either<Failure, Job>> create(Job entity) => _enhanced.create(entity);

  @override
  Future<Either<Failure, Job>> update(Job entity) => _enhanced.update(entity);

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
  Stream<Job> watchJob(String jobId) => _original.watchJob(jobId);

  @override
  Future<Either<Failure, List<Job>>> getActiveJobs() => _original.getActiveJobs();

  @override
  Future<Either<Failure, List<Job>>> getJobsByStatus(JobStatus status) =>
      _original.getJobsByStatus(status);

  @override
  Future<Either<Failure, void>> cancelJob(String jobId) => _original.cancelJob(jobId);

  @override
  Future<Either<Failure, List<Job>>> getJobHistory({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) => _original.getJobHistory(
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );

  @override
  Future<Either<Failure, Map<String, dynamic>>> getJobStats({
    DateTime? startDate,
    DateTime? endDate,
  }) => _original.getJobStats(startDate: startDate, endDate: endDate);
}