import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/lead.dart';
import '../../domain/entities/lead_timeline_entry.dart';
import '../../domain/repositories/leads_repository.dart';
import '../../domain/usecases/browser_automation_usecase.dart';
import '../datasources/leads_remote_datasource.dart';
import '../models/lead_model.dart';

class LeadsRepositoryImpl implements LeadsRepository {
  final LeadsRemoteDataSource remoteDataSource;

  LeadsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Lead>>> getLeads({
    String? status,
    String? search,
    bool? candidatesOnly,
  }) async {
    try {
      final leadModels = await remoteDataSource.getLeads(
        status: status,
        search: search,
        candidatesOnly: candidatesOnly,
      );
      final leads = leadModels.map((model) => model.toEntity()).toList();
      return Right(leads);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Lead>> getLead(String id) async {
    try {
      final leadModel = await remoteDataSource.getLead(id);
      return Right(leadModel.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Lead>> updateLead(Lead lead) async {
    try {
      final leadModel = LeadModel.fromEntity(lead);
      final updatedModel = await remoteDataSource.updateLead(leadModel);
      return Right(updatedModel.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Lead>> updateTimelineEntry(String leadId, LeadTimelineEntry entry) async {
    try {
      final updates = <String, dynamic>{};
      if (entry.title.isNotEmpty) updates['title'] = entry.title;
      if (entry.description != null) updates['description'] = entry.description;
      
      // Always include follow_up_date, even if null (to clear it)
      updates['follow_up_date'] = entry.followUpDate?.toIso8601String();
      
      updates['is_completed'] = entry.isCompleted;
      if (entry.completedBy != null) updates['completed_by'] = entry.completedBy;
      if (entry.completedAt != null) updates['completed_at'] = entry.completedAt!.toIso8601String();

      final updatedModel = await remoteDataSource.updateTimelineEntry(leadId, entry.id, updates);
      return Right(updatedModel.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addTimelineEntry(String leadId, Map<String, dynamic> entryData) async {
    try {
      await remoteDataSource.addTimelineEntry(leadId, entryData);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> startAutomation(BrowserAutomationParams params) async {
    try {
      final jobId = await remoteDataSource.startAutomation(params);
      return Right(jobId);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<Job> watchJob(String jobId) async* {
    while (true) {
      try {
        final data = await remoteDataSource.getJobStatus(jobId);
        final status = _parseJobStatus(data['status']);
        
        yield Job(
          id: jobId,
          status: status,
          processed: data['processed'] ?? 0,
          total: data['total'] ?? 0,
          message: data['message'],
          industry: data['industry'],
          location: data['location'],
          query: data['query'],
        );

        if (status == JobStatus.done || status == JobStatus.error) {
          break;
        }

        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        yield Job(
          id: jobId,
          status: JobStatus.error,
          processed: 0,
          total: 0,
          message: e.toString(),
          industry: null,
          location: null,
          query: null,
        );
        break;
      }
    }
  }

  JobStatus _parseJobStatus(String? status) {
    switch (status) {
      case 'running':
        return JobStatus.running;
      case 'done':
        return JobStatus.done;
      case 'error':
        return JobStatus.error;
      default:
        return JobStatus.running;
    }
  }

  @override
  Future<Either<Failure, int>> deleteMockLeads() async {
    try {
      final count = await remoteDataSource.deleteMockLeads();
      return Right(count);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, Map<String, dynamic>>> recalculateConversionScores() async {
    try {
      final result = await remoteDataSource.recalculateConversionScores();
      return Right(result);
    } catch (e) {
      // Extract the actual error message without "Exception: " prefix
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11); // Remove "Exception: " prefix
      }
      return Left(ServerFailure(errorMessage));
    }
  }

  @override
  Future<Either<Failure, void>> deleteLead(String id) async {
    try {
      await remoteDataSource.deleteLead(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteLeads(List<String> ids) async {
    try {
      await remoteDataSource.deleteLeads(ids);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}