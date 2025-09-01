import 'package:dio/dio.dart';
import '../models/analytics_models.dart';

class AnalyticsRepository {
  final Dio _dio;

  AnalyticsRepository(this._dio);

  Future<ConversionOverview> getOverview() async {
    try {
      final response = await _dio.get('/analytics/overview');
      return ConversionOverview.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch analytics overview: $e');
    }
  }

  Future<TopSegments> getTopSegments({int limit = 10}) async {
    try {
      final response = await _dio.get(
        '/analytics/segments',
        queryParameters: {'limit': limit},
      );
      return TopSegments.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch top segments: $e');
    }
  }

  Future<List<ConversionTimeline>> getTimeline({int days = 30}) async {
    try {
      final response = await _dio.get(
        '/analytics/timeline',
        queryParameters: {'days': days},
      );
      final timeline = response.data['timeline'] as List;
      return timeline.map((e) => ConversionTimeline.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch timeline: $e');
    }
  }

  Future<List<ActionableInsight>> getInsights() async {
    try {
      final response = await _dio.get('/analytics/insights');
      final insights = response.data['insights'] as List;
      return insights.map((e) => ActionableInsight.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch insights: $e');
    }
  }
}