import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/lead_model.dart';
import '../models/paginated_response.dart';
import '../../domain/usecases/browser_automation_usecase.dart';

abstract class LeadsRemoteDataSource {
  Future<List<LeadModel>> getLeads({
    String? status,
    String? search,
    bool? candidatesOnly,
  });
  Future<PaginatedResponse<LeadModel>> getLeadsPaginated({
    required int page,
    required int perPage,
    String? status,
    String? search,
    bool? candidatesOnly,
    String? sortBy,
    bool? sortAscending,
  });
  Future<PaginatedResponse<LeadModel>> getLeadsCalledToday({
    required int page,
    required int perPage,
  });
  Future<LeadModel> getLead(String id);
  Future<LeadModel> updateLead(LeadModel lead);
  Future<LeadModel> updateTimelineEntry(String leadId, String entryId, Map<String, dynamic> updates);
  Future<void> addTimelineEntry(String leadId, Map<String, dynamic> entryData);
  Future<String> startAutomation(BrowserAutomationParams params);
  Future<Map<String, dynamic>> getJobStatus(String jobId);
  Future<int> deleteMockLeads();
  Future<Map<String, dynamic>> recalculateConversionScores();
  Future<void> deleteLead(String id);
  Future<void> deleteLeads(List<String> ids);
}

class LeadsRemoteDataSourceImpl implements LeadsRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  LeadsRemoteDataSourceImpl({
    required this.dio,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? _getBaseUrl();
  
  static String _getBaseUrl() {
    try {
      return dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
    } catch (_) {
      // In tests, dotenv might not be initialized
      return 'http://localhost:8000';
    }
  }

  @override
  Future<List<LeadModel>> getLeads({
    String? status,
    String? search,
    bool? candidatesOnly,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'pagination': false,  // Maintain backwards compatibility
      };
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
  Future<PaginatedResponse<LeadModel>> getLeadsPaginated({
    required int page,
    required int perPage,
    String? status,
    String? search,
    bool? candidatesOnly,
    String? sortBy,
    bool? sortAscending,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        'pagination': true,
      };
      
      if (status != null) queryParams['status'] = status;
      if (search != null) queryParams['search'] = search;
      if (candidatesOnly == true) queryParams['candidates_only'] = true;
      if (sortBy != null) queryParams['sort_by'] = sortBy;
      if (sortAscending != null) queryParams['sort_ascending'] = sortAscending;

      print('🌐 API REQUEST: GET $baseUrl/leads');
      print('🌐 API PARAMS: $queryParams');
      
      // Highlight sorting parameters
      if (sortBy != null || sortAscending != null) {
        print('🔄 SORT REQUEST: Sorting by $sortBy (${sortAscending == true ? "ascending" : "descending"})');
      }
      
      final response = await dio.get(
        '$baseUrl/leads',
        queryParameters: queryParams,
      );

      print('🌐 API RESPONSE: Status ${response.statusCode}');
      print('🌐 API RESPONSE: ${response.data['items']?.length ?? 0} items, total: ${response.data['total']}, pages: ${response.data['total_pages']}');
      
      // Parse paginated response
      return PaginatedResponse<LeadModel>.fromJson(
        response.data,
        (json) => LeadModel.fromJson(json as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      print('🌐 API ERROR: Failed to get paginated leads - ${e.message}');
      print('🌐 API ERROR: Response data: ${e.response?.data}');
      throw Exception('Failed to get paginated leads: ${e.message}');
    }
  }

  @override
  Future<PaginatedResponse<LeadModel>> getLeadsCalledToday({
    required int page,
    required int perPage,
  }) async {
    try {
      print('📡 Fetching leads called today - page $page, per_page $perPage');
      
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };
      
      final response = await dio.get(
        '$baseUrl/leads/called-today',
        queryParameters: queryParams,
      );
      
      // Parse the response
      final leads = (response.data['leads'] as List)
          .map((json) => LeadModel.fromJson(json))
          .toList();
      
      final total = response.data['total'] ?? 0;
      final totalPages = response.data['total_pages'] ?? 1;
      final hasNext = page < totalPages;
      
      print('📡 Called today response: ${leads.length} leads (page $page of $totalPages)');
      
      return PaginatedResponse(
        items: leads,
        page: page,
        perPage: perPage,
        total: total,
        totalPages: totalPages,
        hasNext: hasNext,
        hasPrev: page > 1,
      );
    } on DioException catch (e) {
      print('❌ Failed to get leads called today: ${e.message}');
      throw Exception('Failed to get leads called today: ${e.message}');
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
  Future<String> startAutomation(BrowserAutomationParams params) async {
    try {
      // Determine if this is a multi-industry or multi-location job
      final hasMultipleIndustries = params.industries.length > 1;
      final hasMultipleLocations = params.locations.length > 1;
      final useParallel = hasMultipleIndustries || hasMultipleLocations;
      
      print('🔧 CLIENT DEBUG: Starting automation with ${params.industries.length} industries and ${params.locations.length} locations');
      print('🔧 CLIENT DEBUG: Industries: ${params.industries}');
      print('🔧 CLIENT DEBUG: Locations: ${params.locations}');
      
      Map<String, dynamic> requestData;
      String endpoint;
      
      if (useParallel) {
        // Use parallel endpoint for multiple industries or locations
        endpoint = '$baseUrl/jobs/parallel';
        requestData = {
          'industries': params.industries.isNotEmpty ? params.industries : [params.industry],
          'locations': params.locations.isNotEmpty ? params.locations : [params.location],
          'limit': params.limit,
          'min_rating': params.minRating,
          'min_reviews': params.minReviews,
          'requires_website': params.requiresWebsite,
          'recent_review_months': params.recentReviewMonths,
          'enable_pagespeed': params.enablePagespeed,
          'max_pagespeed_score': params.maxPagespeedScore,
        };
      } else {
        // Use single job endpoint
        endpoint = '$baseUrl/jobs/browser';
        requestData = {
          'industry': params.industry,
          'location': params.location,
          'locations': params.locations,  // Pass locations array for future support
          'limit': params.limit,
          'min_rating': params.minRating,
          'min_reviews': params.minReviews,
          'recent_days': params.recentDays,
          'mock': params.mock,
          'use_mock_data': params.mock,
          'use_browser_automation': params.useBrowserAutomation ?? true,
          'headless': params.headless,
          'use_profile': params.useProfile,
          'requires_website': params.requiresWebsite,
          'recent_review_months': params.recentReviewMonths,
          'min_photos': params.minPhotos,
          'min_description_length': params.minDescriptionLength,
          'enable_pagespeed': params.enablePagespeed,
          'max_pagespeed_score': params.maxPagespeedScore,
        };
      }
      
      print('🔧 CLIENT DEBUG: Using endpoint: $endpoint');
      print('🔧 CLIENT DEBUG: Request data: $requestData');
      
      final response = await dio.post(endpoint, data: requestData);
      
      print('🔧 CLIENT DEBUG: Response data: ${response.data}');
      
      // Handle response based on endpoint type
      String? jobId;
      if (useParallel) {
        // Parallel endpoint returns parent_job_id
        jobId = response.data['parent_job_id'];
        print('🔧 CLIENT DEBUG: Using parent_job_id from parallel endpoint: $jobId');
      } else {
        // Single job endpoint returns job_id
        jobId = response.data['job_id'];
        print('🔧 CLIENT DEBUG: Using job_id from single endpoint: $jobId');
      }
      
      if (jobId == null) {
        throw Exception('Server did not return a job ID');
      }
      return jobId.toString();
    } on DioException catch (e) {
      throw Exception('Failed to start browser automation: ${e.message}');
    }
  }

  @override
  Future<LeadModel> updateLead(LeadModel lead) async {
    try {
      // Build update data - only send fields that can be updated
      final updateData = <String, dynamic>{
        'status': lead.status,  // status is already a String in LeadModel
      };
      
      // Add optional fields if they exist
      if (lead.notes != null) {
        updateData['notes'] = lead.notes;
      }
      if (lead.followUpDate != null) {
        updateData['follow_up_date'] = lead.followUpDate!.toIso8601String();
      }
      
      print('🔄 Updating lead ${lead.id} with data: $updateData');
      print('📡 PUT $baseUrl/leads/${lead.id}');
      
      final response = await dio.put(
        '$baseUrl/leads/${lead.id}',
        data: updateData,
      );
      
      print('✅ Lead update response: ${response.statusCode}');
      print('📦 Response data status: ${response.data['status']}');
      
      return LeadModel.fromJson(response.data);
    } on DioException catch (e) {
      print('❌ Failed to update lead: ${e.response?.data}');
      throw Exception('Failed to update lead: ${e.message}');
    }
  }

  @override
  Future<LeadModel> updateTimelineEntry(String leadId, String entryId, Map<String, dynamic> updates) async {
    try {
      final response = await dio.put(
        '$baseUrl/leads/$leadId/timeline/$entryId',
        data: updates,
      );
      return LeadModel.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to update timeline entry: ${e.message}');
    }
  }

  @override
  Future<void> addTimelineEntry(String leadId, Map<String, dynamic> entryData) async {
    try {
      print('🌐 POST $baseUrl/leads/$leadId/timeline');
      print('📤 Request data: $entryData');
      
      final response = await dio.post('$baseUrl/leads/$leadId/timeline', data: entryData);
      
      print('✅ Timeline entry added successfully: ${response.statusCode}');
    } on DioException catch (e) {
      print('❌ Failed to add timeline entry: ${e.response?.statusCode} - ${e.response?.data}');
      print('❌ Error type: ${e.type}');
      print('❌ Error message: ${e.message}');
      throw Exception('Failed to add timeline entry: ${e.message}');
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
  
  @override
  Future<Map<String, dynamic>> recalculateConversionScores() async {
    try {
      final response = await dio.post('$baseUrl/conversion/calculate');
      
      // Check if response is successful
      if (response.statusCode == 200) {
        // Parse response to ensure it's valid
        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          // Return the full response data for better UI feedback
          return data;
        }
        throw Exception('Invalid response format');
      }
      
      throw Exception('Server returned ${response.statusCode}');
    } on DioException catch (e) {
      // Provide more detailed error information
      if (e.response != null) {
        throw Exception('Server error: ${e.response?.statusCode} - ${e.response?.data}');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout - server may be processing');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Connection error - check if server is running');
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      // Catch any other errors
      throw Exception('Unexpected error: $e');
    }
  }

  @override
  Future<void> deleteLead(String id) async {
    try {
      await dio.delete('$baseUrl/leads/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete lead: ${e.message}');
    }
  }

  @override
  Future<void> deleteLeads(List<String> ids) async {
    // Since there's no bulk delete endpoint, delete one by one
    final errors = <String>[];
    for (final id in ids) {
      try {
        await dio.delete('$baseUrl/leads/$id');
      } on DioException catch (e) {
        errors.add('Failed to delete $id: ${e.message}');
      }
    }
    if (errors.isNotEmpty) {
      throw Exception('Some leads failed to delete: ${errors.join(', ')}');
    }
  }
}