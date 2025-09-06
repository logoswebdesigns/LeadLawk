import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/lead_timeline_entry.dart';
import '../../domain/repositories/lead_timeline_repository.dart';
import '../datasources/lead_timeline_remote_datasource.dart';
import '../models/lead_timeline_entry_model.dart';

class LeadTimelineRepositoryImpl implements LeadTimelineRepository {
  final LeadTimelineRemoteDataSource remoteDataSource;

  LeadTimelineRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<LeadTimelineEntry>>> getAll({
    Map<String, dynamic>? filters,
  }) async {
    try {
      final models = await remoteDataSource.getAllTimelineEntries();
      final entries = models.map((model) => model.toEntity()).toList();
      return Right(entries);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LeadTimelineEntry>> getById(String id) async {
    try {
      final model = await remoteDataSource.getTimelineEntryById(id);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LeadTimelineEntry>> create(LeadTimelineEntry entity) async {
    try {
      final model = LeadTimelineEntryModel.fromEntity(entity);
      final createdModel = await remoteDataSource.createTimelineEntry(model);
      return Right(createdModel.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LeadTimelineEntry>> update(LeadTimelineEntry entity) async {
    try {
      final model = LeadTimelineEntryModel.fromEntity(entity);
      final updatedModel = await remoteDataSource.updateTimelineEntry(model);
      return Right(updatedModel.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> delete(String id) async {
    try {
      await remoteDataSource.deleteTimelineEntry(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMany(List<String> ids) async {
    try {
      for (final id in ids) {
        await remoteDataSource.deleteTimelineEntry(id);
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> exists(String id) async {
    try {
      await remoteDataSource.getTimelineEntryById(id);
      return const Right(true);
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, int>> count({Map<String, dynamic>? filters}) async {
    try {
      final entries = await remoteDataSource.getAllTimelineEntries();
      return Right(entries.length);
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
  Future<Either<Failure, List<LeadTimelineEntry>>> getTimelineForLead(
    String leadId, {
    int? limit,
    DateTime? since,
  }) async {
    try {
      final models = await remoteDataSource.getTimelineForLead(
        leadId,
        limit: limit,
        since: since,
      );
      final entries = models.map((model) => model.toEntity()).toList();
      return Right(entries);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LeadTimelineEntry>>> getTimelineByType(
    String entryType, {
    String? leadId,
    int? limit,
  }) async {
    try {
      final models = await remoteDataSource.getTimelineByType(
        entryType,
        leadId: leadId,
        limit: limit,
      );
      final entries = models.map((model) => model.toEntity()).toList();
      return Right(entries);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LeadTimelineEntry>>> getPendingFollowUps({
    DateTime? dueDate,
    bool overdue = false,
  }) async {
    try {
      final models = await remoteDataSource.getPendingFollowUps(
        dueDate: dueDate,
        overdue: overdue,
      );
      final entries = models.map((model) => model.toEntity()).toList();
      return Right(entries);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LeadTimelineEntry>> markAsCompleted(
    String entryId, {
    String? completedBy,
    DateTime? completedAt,
  }) async {
    try {
      final model = await remoteDataSource.markAsCompleted(
        entryId,
        completedBy: completedBy,
        completedAt: completedAt,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getTimelineStats({
    DateTime? startDate,
    DateTime? endDate,
    String? leadId,
  }) async {
    try {
      final stats = await remoteDataSource.getTimelineStats(
        startDate: startDate,
        endDate: endDate,
        leadId: leadId,
      );
      return Right(stats);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LeadTimelineEntry>>> createBulk(
    List<LeadTimelineEntry> entries,
  ) async {
    try {
      final createdEntries = <LeadTimelineEntry>[];
      for (final entry in entries) {
        final model = LeadTimelineEntryModel.fromEntity(entry);
        final createdModel = await remoteDataSource.createTimelineEntry(model);
        createdEntries.add(createdModel.toEntity());
      }
      return Right(createdEntries);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LeadTimelineEntry>>> getRecentActivity({
    int limit = 50,
    List<String>? entryTypes,
  }) async {
    try {
      final models = await remoteDataSource.getRecentActivity(
        limit: limit,
        entryTypes: entryTypes,
      );
      final entries = models.map((model) => model.toEntity()).toList();
      return Right(entries);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}