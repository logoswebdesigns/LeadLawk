import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/lead_model.dart';
import '../../domain/usecases/browser_automation_usecase.dart';

abstract class LeadsRemoteDataSource {
  Future<List<LeadModel>> getLeads({
    String? status,
    String? search,
    bool? candidatesOnly,
  });
  Future<LeadModel> getLead(String id);
  Future<LeadModel> updateLead(LeadModel lead);
  Future<String> startAutomation(BrowserAutomationParams params);
  Future<Map<String, dynamic>> getJobStatus(String jobId);
  Future<int> deleteMockLeads();
}

class LeadsRemoteDataSourceImpl implements LeadsRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  LeadsRemoteDataSourceImpl({
    required this.dio,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? dotenv.env['BASE_URL'] ?? 'http://localhost:8000';

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
  Future<String> startAutomation(BrowserAutomationParams params) async {
    try {
      // Always use browser automation endpoint
      final endpoint = '$baseUrl/jobs/browser';
      
      final response = await dio.post(
        endpoint,
        data: {
          'industry': params.industry,
          'location': params.location,
          'limit': params.limit,
          'min_rating': params.minRating,
          'min_reviews': params.minReviews,
          'recent_days': params.recentDays,
          'mock': params.mock,
          'use_mock_data': params.mock,  // Use mock data toggle
          'use_browser_automation': params.useBrowserAutomation ?? true,
          'headless': params.headless,  // User can toggle this in UI
          'use_profile': params.useProfile,
          'requires_website': params.requiresWebsite,  // Website filter
          'recent_review_months': params.recentReviewMonths,  // Recent review filter
          'min_photos': params.minPhotos,  // Photo count filter  
          'min_description_length': params.minDescriptionLength,  // Description quality filter
        },
      );
      return response.data['job_id'];
    } on DioException catch (e) {
      throw Exception('Failed to start browser automation: ${e.message}');
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

  @override
  Future<int> deleteMockLeads() async {
    try {
      final response = await dio.delete('$baseUrl/admin/leads/mock');
      return response.data['deleted'] ?? 0;
    } on DioException catch (e) {
      throw Exception('Failed to delete mock leads: ${e.message}');
    }
  }
}