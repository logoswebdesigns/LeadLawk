import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/call_log_model.dart';
import '../../domain/entities/call_log.dart';

abstract class CallLogRemoteDataSource {
  Future<List<CallLogModel>> getAllCallLogs();
  Future<CallLogModel> getCallLogById(String id);
  Future<CallLogModel> createCallLog(CallLogModel callLog);
  Future<CallLogModel> updateCallLog(CallLogModel callLog);
  Future<void> deleteCallLog(String id);
  Future<List<CallLogModel>> getCallLogsForLead(String leadId);
  Future<List<CallLogModel>> getRecentCallLogs({int limit = 50, DateTime? since});
  Future<List<CallLogModel>> getCallLogsByOutcome(CallOutcome outcome);
  Future<Map<String, dynamic>> getCallStats({
    DateTime? startDate,
    DateTime? endDate,
    String? leadId,
  });
  Future<CallLogModel> startCall(String leadId, String phoneNumber);
  Future<CallLogModel> endCall(String callId, CallOutcome outcome, {
    String? notes,
    String? recordingUrl,
  });
}

class CallLogRemoteDataSourceImpl implements CallLogRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  CallLogRemoteDataSourceImpl({
    required this.dio,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? _getBaseUrl();

  static String _getBaseUrl() {
    try {
      return dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
    } catch (e) {
      return 'http://localhost:8000';
    }
  }

  @override
  Future<List<CallLogModel>> getAllCallLogs() async {
    final response = await dio.get('$baseUrl/api/call-logs');
    return (response.data as List)
        .map((json) => CallLogModel.fromJson(json))
        .toList();
  }

  @override
  Future<CallLogModel> getCallLogById(String id) async {
    final response = await dio.get('$baseUrl/api/call-logs/$id');
    return CallLogModel.fromJson(response.data);
  }

  @override
  Future<CallLogModel> createCallLog(CallLogModel callLog) async {
    final response = await dio.post('$baseUrl/api/call-logs', 
        data: callLog.toJson());
    return CallLogModel.fromJson(response.data);
  }

  @override
  Future<CallLogModel> updateCallLog(CallLogModel callLog) async {
    final response = await dio.put('$baseUrl/api/call-logs/${callLog.id}', 
        data: callLog.toJson());
    return CallLogModel.fromJson(response.data);
  }

  @override
  Future<void> deleteCallLog(String id) async {
    await dio.delete('$baseUrl/api/call-logs/$id');
  }

  @override
  Future<List<CallLogModel>> getCallLogsForLead(String leadId) async {
    final response = await dio.get('$baseUrl/api/call-logs', 
        queryParameters: {'lead_id': leadId});
    return (response.data as List)
        .map((json) => CallLogModel.fromJson(json))
        .toList();
  }

  @override
  Future<List<CallLogModel>> getRecentCallLogs({
    int limit = 50, 
    DateTime? since
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (since != null) params['since'] = since.toIso8601String();

    final response = await dio.get('$baseUrl/api/call-logs/recent', 
        queryParameters: params);
    return (response.data as List)
        .map((json) => CallLogModel.fromJson(json))
        .toList();
  }

  @override
  Future<List<CallLogModel>> getCallLogsByOutcome(CallOutcome outcome) async {
    final response = await dio.get('$baseUrl/api/call-logs', 
        queryParameters: {
          'outcome': outcome.toString().split('.').last,
        });
    return (response.data as List)
        .map((json) => CallLogModel.fromJson(json))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getCallStats({
    DateTime? startDate,
    DateTime? endDate,
    String? leadId,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate.toIso8601String();
    if (endDate != null) params['end_date'] = endDate.toIso8601String();
    if (leadId != null) params['lead_id'] = leadId;

    final response = await dio.get('$baseUrl/api/call-logs/stats', 
        queryParameters: params);
    return response.data;
  }

  @override
  Future<CallLogModel> startCall(String leadId, String phoneNumber) async {
    final response = await dio.post('$baseUrl/api/call-logs/start', data: {
      'lead_id': leadId,
      'phone_number': phoneNumber,
    });
    return CallLogModel.fromJson(response.data);
  }

  @override
  Future<CallLogModel> endCall(String callId, CallOutcome outcome, {
    String? notes,
    String? recordingUrl,
  }) async {
    final data = <String, dynamic>{
      'outcome': outcome.toString().split('.').last,
    };
    if (notes != null) data['notes'] = notes;
    if (recordingUrl != null) data['recording_url'] = recordingUrl;

    final response = await dio.post('$baseUrl/api/call-logs/$callId/end', 
        data: data);
    return CallLogModel.fromJson(response.data);
  }
}