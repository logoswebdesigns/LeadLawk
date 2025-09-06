import 'package:dio/dio.dart';

class ParallelSearchDataSource {
  final Dio _dio;
  
  ParallelSearchDataSource(this._dio);
  
  Future<Map<String, dynamic>> startParallelSearch({
    required List<String> industries,
    required List<String> locations,
    required int limit,
    double minRating = 0.0,
    int minReviews = 0,
    bool requiresWebsite = false,
    int recentReviewMonths = 24,
    bool enablePagespeed = false,
  }) async {
    try {
      final response = await _dio.post(
        '/jobs/parallel',
        data: {
          'industries': industries,
          'locations': locations,
          'limit': limit,
          'min_rating': minRating,
          'min_reviews': minReviews,
          'requires_website': requiresWebsite,
          'recent_review_months': recentReviewMonths,
          'enable_pagespeed': enablePagespeed,
        },
      );
      
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 503) {
        throw Exception('Selenium Grid not ready. Please try again in a moment.');
      }
      throw Exception('Failed to start parallel search: ${e.message}');
    }
  }
  
  Future<Map<String, dynamic>> getParallelJobStatus(String parentJobId) async {
    try {
      final response = await _dio.get('/jobs/$parentJobId/status');
      return response.data;
    } catch (e) {
      throw Exception('Failed to get job status: $e');
    }
  }
  
  Future<void> cancelParallelJob(String parentJobId) async {
    try {
      await _dio.post('/jobs/$parentJobId/cancel');
    } catch (e) {
      throw Exception('Failed to cancel job: $e');
    }
  }
}