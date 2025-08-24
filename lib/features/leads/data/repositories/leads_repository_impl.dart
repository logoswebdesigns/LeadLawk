import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/lead.dart';
import '../../domain/repositories/leads_repository.dart';
import '../../domain/usecases/run_scrape_usecase.dart';
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
  Future<Either<Failure, String>> startScrape(RunScrapeParams params) async {
    try {
      final jobId = await remoteDataSource.startScrape(params);
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
}