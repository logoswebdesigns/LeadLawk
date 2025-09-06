import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/repositories/base_repository.dart';
import '../entities/call_log.dart';

abstract class CallLogRepository implements BaseRepository<CallLog> {
  /// Get call logs for a specific lead
  Future<Either<Failure, List<CallLog>>> getCallLogsForLead(String leadId);
  
  /// Get recent call logs
  Future<Either<Failure, List<CallLog>>> getRecentCallLogs({
    int limit = 50,
    DateTime? since,
  });
  
  /// Get call logs by outcome
  Future<Either<Failure, List<CallLog>>> getCallLogsByOutcome(
    CallOutcome outcome,
  );
  
  /// Get call statistics
  Future<Either<Failure, Map<String, dynamic>>> getCallStats({
    DateTime? startDate,
    DateTime? endDate,
    String? leadId,
  });
  
  /// Get total call duration
  Future<Either<Failure, Duration>> getTotalCallDuration({
    DateTime? startDate,
    DateTime? endDate,
    String? leadId,
  });
  
  /// Start a new call
  Future<Either<Failure, CallLog>> startCall(String leadId, String phoneNumber);
  
  /// End a call
  Future<Either<Failure, CallLog>> endCall(String callId, CallOutcome outcome, {
    String? notes,
    String? recordingUrl,
  });
}