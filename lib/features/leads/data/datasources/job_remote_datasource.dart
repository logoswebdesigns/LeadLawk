import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/job_model.dart';
import '../../domain/entities/job.dart';

abstract class JobRemoteDataSource {
  Future<List<JobModel>> getAllJobs();
  Future<JobModel> getJobById(String id);
  Future<List<JobModel>> getActiveJobs();
  Future<List<JobModel>> getJobsByStatus(JobStatus status);
  Future<void> cancelJob(String jobId);
  Future<List<JobModel>> getJobHistory({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });
  Future<Map<String, dynamic>> getJobStats({
    DateTime? startDate,
    DateTime? endDate,
  });
  Stream<JobModel> watchJob(String jobId);
}

class JobRemoteDataSourceImpl implements JobRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  JobRemoteDataSourceImpl({
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
  Future<List<JobModel>> getAllJobs() async {
    final response = await dio.get('$baseUrl/api/jobs');
    return (response.data as List)
        .map((json) => JobModel.fromJson(json))
        .toList();
  }

  @override
  Future<JobModel> getJobById(String id) async {
    final response = await dio.get('$baseUrl/api/jobs/$id');
    return JobModel.fromJson(response.data);
  }

  @override
  Future<List<JobModel>> getActiveJobs() async {
    final response = await dio.get('$baseUrl/api/jobs/active');
    return (response.data as List)
        .map((json) => JobModel.fromJson(json))
        .toList();
  }

  @override
  Future<List<JobModel>> getJobsByStatus(JobStatus status) async {
    final response = await dio.get('$baseUrl/api/jobs', queryParameters: {
      'status': status.toString().split('.').last,
    });
    return (response.data as List)
        .map((json) => JobModel.fromJson(json))
        .toList();
  }

  @override
  Future<void> cancelJob(String jobId) async {
    await dio.post('$baseUrl/api/jobs/$jobId/cancel');
  }

  @override
  Future<List<JobModel>> getJobHistory({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate.toIso8601String();
    if (endDate != null) params['end_date'] = endDate.toIso8601String();
    if (limit != null) params['limit'] = limit;

    final response = await dio.get('$baseUrl/api/jobs/history', 
        queryParameters: params);
    return (response.data as List)
        .map((json) => JobModel.fromJson(json))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getJobStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate.toIso8601String();
    if (endDate != null) params['end_date'] = endDate.toIso8601String();

    final response = await dio.get('$baseUrl/api/jobs/stats', 
        queryParameters: params);
    return response.data;
  }

  @override
  Stream<JobModel> watchJob(String jobId) async* {
    // Implementation would depend on WebSocket or polling mechanism
    // For now, return a simple polling implementation
    while (true) {
      try {
        final job = await getJobById(jobId);
        yield job;
        
        if (job.status == 'done' || job.status == 'error') {
          break;
        }
        
        await Future.delayed(Duration(seconds: 1));
      } catch (e) {
        break;
      }
    }
  }
}