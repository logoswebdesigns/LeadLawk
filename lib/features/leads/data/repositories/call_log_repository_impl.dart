import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/call_log.dart';
import '../../domain/repositories/call_log_repository.dart';
import '../datasources/call_log_remote_datasource.dart';
import '../models/call_log_model.dart';

class CallLogRepositoryImpl implements CallLogRepository {
  final CallLogRemoteDataSource remoteDataSource;

  CallLogRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<CallLog>>> getAll({Map<String, dynamic>? filters}) async {
    try {
      final callLogModels = await remoteDataSource.getAllCallLogs();
      final callLogs = callLogModels.map((model) => model.toEntity()).toList();
      return Right(callLogs);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CallLog>> getById(String id) async {
    try {
      final callLogModel = await remoteDataSource.getCallLogById(id);
      return Right(callLogModel.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CallLog>> create(CallLog entity) async {
    try {
      final callLogModel = CallLogModel.fromEntity(entity);
      final createdModel = await remoteDataSource.createCallLog(callLogModel);
      return Right(createdModel.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CallLog>> update(CallLog entity) async {
    try {
      final callLogModel = CallLogModel.fromEntity(entity);
      final updatedModel = await remoteDataSource.updateCallLog(callLogModel);
      return Right(updatedModel.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> delete(String id) async {
    try {
      await remoteDataSource.deleteCallLog(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMany(List<String> ids) async {
    try {
      for (final id in ids) {
        await remoteDataSource.deleteCallLog(id);
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> exists(String id) async {
    try {
      await remoteDataSource.getCallLogById(id);
      return const Right(true);
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, int>> count({Map<String, dynamic>? filters}) async {
    try {
      final callLogs = await remoteDataSource.getAllCallLogs();
      return Right(callLogs.length);
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
  Future<Either<Failure, List<CallLog>>> getCallLogsForLead(String leadId) async {
    try {
      final callLogModels = await remoteDataSource.getCallLogsForLead(leadId);
      final callLogs = callLogModels.map((model) => model.toEntity()).toList();
      return Right(callLogs);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CallLog>>> getRecentCallLogs({
    int limit = 50,
    DateTime? since,
  }) async {
    try {
      final callLogModels = await remoteDataSource.getRecentCallLogs(
        limit: limit,
        since: since,
      );
      final callLogs = callLogModels.map((model) => model.toEntity()).toList();
      return Right(callLogs);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CallLog>>> getCallLogsByOutcome(
    CallOutcome outcome,
  ) async {
    try {
      final callLogModels = await remoteDataSource.getCallLogsByOutcome(outcome);
      final callLogs = callLogModels.map((model) => model.toEntity()).toList();
      return Right(callLogs);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getCallStats({
    DateTime? startDate,
    DateTime? endDate,
    String? leadId,
  }) async {
    try {
      final stats = await remoteDataSource.getCallStats(
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
  Future<Either<Failure, Duration>> getTotalCallDuration({
    DateTime? startDate,
    DateTime? endDate,
    String? leadId,
  }) async {
    try {
      final stats = await remoteDataSource.getCallStats(
        startDate: startDate,
        endDate: endDate,
        leadId: leadId,
      );
      final totalSeconds = stats['total_duration_seconds'] as int? ?? 0;
      return Right(Duration(seconds: totalSeconds));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CallLog>> startCall(String leadId, String phoneNumber) async {
    try {
      final callLogModel = await remoteDataSource.startCall(leadId, phoneNumber);
      return Right(callLogModel.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CallLog>> endCall(String callId, CallOutcome outcome, {
    String? notes,
    String? recordingUrl,
  }) async {
    try {
      final callLogModel = await remoteDataSource.endCall(
        callId,
        outcome,
        notes: notes,
        recordingUrl: recordingUrl,
      );
      return Right(callLogModel.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}