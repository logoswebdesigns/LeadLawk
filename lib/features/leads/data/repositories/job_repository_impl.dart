import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/job.dart';
import '../../domain/repositories/job_repository.dart';
import '../datasources/job_remote_datasource.dart';

class JobRepositoryImpl implements JobRepository {
  final JobRemoteDataSource remoteDataSource;

  JobRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Job>>> getAll({Map<String, dynamic>? filters}) async {
    try {
      final jobModels = await remoteDataSource.getAllJobs();
      final jobs = jobModels.map((model) => model.toEntity()).toList();
      return Right(jobs);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Job>> getById(String id) async {
    try {
      final jobModel = await remoteDataSource.getJobById(id);
      return Right(jobModel.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Job>> create(Job entity) async {
    return const Left(ValidationFailure('Job creation not supported through repository'));
  }

  @override
  Future<Either<Failure, Job>> update(Job entity) async {
    return const Left(ValidationFailure('Job updates not supported through repository'));
  }

  @override
  Future<Either<Failure, void>> delete(String id) async {
    try {
      await remoteDataSource.cancelJob(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMany(List<String> ids) async {
    try {
      for (final id in ids) {
        await remoteDataSource.cancelJob(id);
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> exists(String id) async {
    try {
      await remoteDataSource.getJobById(id);
      return const Right(true);
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, int>> count({Map<String, dynamic>? filters}) async {
    try {
      final jobs = await remoteDataSource.getAllJobs();
      return Right(jobs.length);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearCache() async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> refresh() async {
    return const Right(null);
  }

  @override
  Stream<Job> watchJob(String jobId) {
    return remoteDataSource.watchJob(jobId).map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, List<Job>>> getActiveJobs() async {
    try {
      final jobModels = await remoteDataSource.getActiveJobs();
      final jobs = jobModels.map((model) => model.toEntity()).toList();
      return Right(jobs);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Job>>> getJobsByStatus(JobStatus status) async {
    try {
      final jobModels = await remoteDataSource.getJobsByStatus(status);
      final jobs = jobModels.map((model) => model.toEntity()).toList();
      return Right(jobs);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelJob(String jobId) async {
    try {
      await remoteDataSource.cancelJob(jobId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Job>>> getJobHistory({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final jobModels = await remoteDataSource.getJobHistory(
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
      final jobs = jobModels.map((model) => model.toEntity()).toList();
      return Right(jobs);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getJobStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final stats = await remoteDataSource.getJobStats(
        startDate: startDate,
        endDate: endDate,
      );
      return Right(stats);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}