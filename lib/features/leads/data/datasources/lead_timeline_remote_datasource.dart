import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/lead_timeline_entry_model.dart';

abstract class LeadTimelineRemoteDataSource {
  Future<List<LeadTimelineEntryModel>> getAllTimelineEntries();
  Future<LeadTimelineEntryModel> getTimelineEntryById(String id);
  Future<LeadTimelineEntryModel> createTimelineEntry(LeadTimelineEntryModel entry);
  Future<LeadTimelineEntryModel> updateTimelineEntry(LeadTimelineEntryModel entry);
  Future<void> deleteTimelineEntry(String id);
  Future<List<LeadTimelineEntryModel>> getTimelineForLead(
    String leadId, {
    int? limit,
    DateTime? since,
  });
  Future<List<LeadTimelineEntryModel>> getTimelineByType(
    String entryType, {
    String? leadId,
    int? limit,
  });
  Future<List<LeadTimelineEntryModel>> getPendingFollowUps({
    DateTime? dueDate,
    bool overdue = false,
  });
  Future<LeadTimelineEntryModel> markAsCompleted(
    String entryId, {
    String? completedBy,
    DateTime? completedAt,
  });
  Future<Map<String, dynamic>> getTimelineStats({
    DateTime? startDate,
    DateTime? endDate,
    String? leadId,
  });
  Future<List<LeadTimelineEntryModel>> getRecentActivity({
    int limit = 50,
    List<String>? entryTypes,
  });
}

class LeadTimelineRemoteDataSourceImpl implements LeadTimelineRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  LeadTimelineRemoteDataSourceImpl({
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
  Future<List<LeadTimelineEntryModel>> getAllTimelineEntries() async {
    final response = await dio.get('$baseUrl/api/timeline');
    return (response.data as List)
        .map((json) => LeadTimelineEntryModel.fromJson(json))
        .toList();
  }

  @override
  Future<LeadTimelineEntryModel> getTimelineEntryById(String id) async {
    final response = await dio.get('$baseUrl/api/timeline/$id');
    return LeadTimelineEntryModel.fromJson(response.data);
  }

  @override
  Future<LeadTimelineEntryModel> createTimelineEntry(
      LeadTimelineEntryModel entry) async {
    final response = await dio.post('$baseUrl/api/timeline', 
        data: entry.toJson());
    return LeadTimelineEntryModel.fromJson(response.data);
  }

  @override
  Future<LeadTimelineEntryModel> updateTimelineEntry(
      LeadTimelineEntryModel entry) async {
    final response = await dio.put('$baseUrl/api/timeline/${entry.id}', 
        data: entry.toJson());
    return LeadTimelineEntryModel.fromJson(response.data);
  }

  @override
  Future<void> deleteTimelineEntry(String id) async {
    await dio.delete('$baseUrl/api/timeline/$id');
  }

  @override
  Future<List<LeadTimelineEntryModel>> getTimelineForLead(
    String leadId, {
    int? limit,
    DateTime? since,
  }) async {
    final params = <String, dynamic>{'lead_id': leadId};
    if (limit != null) params['limit'] = limit;
    if (since != null) params['since'] = since.toIso8601String();

    final response = await dio.get('$baseUrl/api/timeline', 
        queryParameters: params);
    return (response.data as List)
        .map((json) => LeadTimelineEntryModel.fromJson(json))
        .toList();
  }

  @override
  Future<List<LeadTimelineEntryModel>> getTimelineByType(
    String entryType, {
    String? leadId,
    int? limit,
  }) async {
    final params = <String, dynamic>{'entry_type': entryType};
    if (leadId != null) params['lead_id'] = leadId;
    if (limit != null) params['limit'] = limit;

    final response = await dio.get('$baseUrl/api/timeline', 
        queryParameters: params);
    return (response.data as List)
        .map((json) => LeadTimelineEntryModel.fromJson(json))
        .toList();
  }

  @override
  Future<List<LeadTimelineEntryModel>> getPendingFollowUps({
    DateTime? dueDate,
    bool overdue = false,
  }) async {
    final params = <String, dynamic>{'pending': true, 'overdue': overdue};
    if (dueDate != null) params['due_date'] = dueDate.toIso8601String();

    final response = await dio.get('$baseUrl/api/timeline/follow-ups', 
        queryParameters: params);
    return (response.data as List)
        .map((json) => LeadTimelineEntryModel.fromJson(json))
        .toList();
  }

  @override
  Future<LeadTimelineEntryModel> markAsCompleted(
    String entryId, {
    String? completedBy,
    DateTime? completedAt,
  }) async {
    final data = <String, dynamic>{'completed': true};
    if (completedBy != null) data['completed_by'] = completedBy;
    if (completedAt != null) data['completed_at'] = completedAt.toIso8601String();

    final response = await dio.patch('$baseUrl/api/timeline/$entryId', 
        data: data);
    return LeadTimelineEntryModel.fromJson(response.data);
  }

  @override
  Future<Map<String, dynamic>> getTimelineStats({
    DateTime? startDate,
    DateTime? endDate,
    String? leadId,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate.toIso8601String();
    if (endDate != null) params['end_date'] = endDate.toIso8601String();
    if (leadId != null) params['lead_id'] = leadId;

    final response = await dio.get('$baseUrl/api/timeline/stats', 
        queryParameters: params);
    return response.data;
  }

  @override
  Future<List<LeadTimelineEntryModel>> getRecentActivity({
    int limit = 50,
    List<String>? entryTypes,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (entryTypes != null) params['entry_types'] = entryTypes.join(',');

    final response = await dio.get('$baseUrl/api/timeline/recent', 
        queryParameters: params);
    return (response.data as List)
        .map((json) => LeadTimelineEntryModel.fromJson(json))
        .toList();
  }
}