import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/repositories/base_repository.dart';
import '../entities/job.dart';

abstract class JobRepository implements BaseRepository<Job> {
  /// Watch job progress in real-time
  Stream<Job> watchJob(String jobId);
  
  /// Get active jobs
  Future<Either<Failure, List<Job>>> getActiveJobs();
  
  /// Get jobs by status
  Future<Either<Failure, List<Job>>> getJobsByStatus(JobStatus status);
  
  /// Cancel job
  Future<Either<Failure, void>> cancelJob(String jobId);
  
  /// Get job history for a date range
  Future<Either<Failure, List<Job>>> getJobHistory({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });
  
  /// Get job statistics
  Future<Either<Failure, Map<String, dynamic>>> getJobStats({
    DateTime? startDate,
    DateTime? endDate,
  });
}