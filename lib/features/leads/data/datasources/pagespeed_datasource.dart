import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PageSpeedDataSource {
  final Dio _dio;
  final String _baseUrl;

  PageSpeedDataSource({Dio? dio}) 
    : _dio = dio ?? Dio(),
      _baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';

  Future<void> testSingleLead(String leadId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/leads/$leadId/pagespeed',
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to start PageSpeed test');
      }
    } catch (e) {
      throw Exception('Failed to start PageSpeed test: $e');
    }
  }

  Future<void> testMultipleLeads(List<String> leadIds) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/leads/pagespeed/bulk',
        data: {
          'lead_ids': leadIds,
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to start bulk PageSpeed tests');
      }
    } catch (e) {
      throw Exception('Failed to start bulk PageSpeed tests: $e');
    }
  }

  Future<Map<String, dynamic>> getTestingStatus() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/leads/pagespeed/status',
      );
      
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      
      throw Exception('Failed to get PageSpeed status');
    } catch (e) {
      throw Exception('Failed to get PageSpeed status: $e');
    }
  }

  Future<void> enableForJob(String jobId, bool enable) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/jobs/$jobId/pagespeed',
        queryParameters: {'enable': enable},
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to update job PageSpeed setting');
      }
    } catch (e) {
      throw Exception('Failed to update job PageSpeed setting: $e');
    }
  }
}