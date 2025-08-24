import 'package:dio/dio.dart';
import '../models/lead_model.dart';
import '../../domain/usecases/run_scrape_usecase.dart';

abstract class LeadsRemoteDataSource {
  Future<List<LeadModel>> getLeads({
    String? status,
    String? search,
    bool? candidatesOnly,
  });
  Future<LeadModel> getLead(String id);
  Future<LeadModel> updateLead(LeadModel lead);
  Future<String> startScrape(RunScrapeParams params);
  Future<Map<String, dynamic>> getJobStatus(String jobId);
}

class LeadsRemoteDataSourceImpl implements LeadsRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  LeadsRemoteDataSourceImpl({
    required this.dio,
    this.baseUrl = 'http://localhost:8000',
  });

  @override
  Future<List<LeadModel>> getLeads({
    String? status,
    String? search,
    bool? candidatesOnly,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (search != null) queryParams['search'] = search;
      if (candidatesOnly == true) queryParams['candidates_only'] = true;

      final response = await dio.get(
        '$baseUrl/leads',
        queryParameters: queryParams,
      );

      return (response.data as List)
          .map((json) => LeadModel.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to get leads: ${e.message}');
    }
  }

  @override
  Future<LeadModel> getLead(String id) async {
    try {
      final response = await dio.get('$baseUrl/leads/$id');
      return LeadModel.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to get lead: ${e.message}');
    }
  }

  @override
  Future<LeadModel> updateLead(LeadModel lead) async {
    try {
      final response = await dio.put(
        '$baseUrl/leads/${lead.id}',
        data: lead.toJson(),
      );
      return LeadModel.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to update lead: ${e.message}');
    }
  }

  @override
  Future<String> startScrape(RunScrapeParams params) async {
    try {
      final response = await dio.post(
        '$baseUrl/jobs/scrape',
        data: {
          'industry': params.industry,
          'location': params.location,
          'limit': params.limit,
          'min_rating': params.minRating,
          'min_reviews': params.minReviews,
          'recent_days': params.recentDays,
        },
      );
      return response.data['job_id'];
    } on DioException catch (e) {
      throw Exception('Failed to start scrape: ${e.message}');
    }
  }

  @override
  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    try {
      final response = await dio.get('$baseUrl/jobs/$jobId');
      return response.data;
    } on DioException catch (e) {
      throw Exception('Failed to get job status: ${e.message}');
    }
  }
}