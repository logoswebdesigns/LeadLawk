import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/entities/lead.dart';

class LeadStatistics {
  final int total;
  final Map<LeadStatus, int> byStatus;
  final double conversionRate;

  LeadStatistics({
    required this.total,
    required this.byStatus,
    required this.conversionRate,
  });

  factory LeadStatistics.fromJson(Map<String, dynamic> json) {
    final byStatusMap = <LeadStatus, int>{};
    
    if (json['by_status'] != null) {
      (json['by_status'] as Map<String, dynamic>).forEach((key, value) {
        // Map the string key to LeadStatus enum
        LeadStatus? status;
        switch (key) {
          case 'new':
            status = LeadStatus.new_;
            break;
          case 'viewed':
            status = LeadStatus.viewed;
            break;
          case 'called':
            status = LeadStatus.called;
            break;
          case 'callback_scheduled':
          case 'callbackScheduled':  // Handle both snake_case and camelCase
            status = LeadStatus.callbackScheduled;
            break;
          case 'interested':
            status = LeadStatus.interested;
            break;
          case 'converted':
            status = LeadStatus.converted;
            break;
          case 'do_not_call':
          case 'doNotCall':  // Handle both snake_case and camelCase
            status = LeadStatus.doNotCall;
            break;
          case 'did_not_convert':
          case 'didNotConvert':  // Handle both snake_case and camelCase
            status = LeadStatus.didNotConvert;
            break;
          default:
            print('⚠️ Unknown status key: $key with value: $value');
            return; // Skip this iteration
        }
        if (status != null) {
          byStatusMap[status] = value as int;
          print('📊 Mapped $key -> $status = $value');
        }
      });
    }

    final stats = LeadStatistics(
      total: json['total'] ?? 0,
      byStatus: byStatusMap,
      conversionRate: (json['conversion_rate'] ?? 0.0).toDouble(),
    );
    
    // Debug: Print summary
    int sum = 0;
    stats.byStatus.forEach((status, count) {
      sum += count;
      print('📊 Final: $status = $count');
    });
    print('📊 Total from API: ${stats.total}, Sum of stages: $sum');
    
    return stats;
  }
}

final leadStatisticsProvider = FutureProvider.autoDispose<LeadStatistics>((ref) async {
  final dio = Dio();
  
  String baseUrl;
  try {
    baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
  } catch (_) {
    baseUrl = 'http://localhost:8000';
  }
  
  try {
    print('📊 Fetching lead statistics from $baseUrl/leads/statistics/all');
    final response = await dio.get('$baseUrl/leads/statistics/all');
    
    if (response.statusCode == 200) {
      final stats = LeadStatistics.fromJson(response.data);
      print('📊 Statistics loaded: ${stats.total} total leads');
      return stats;
    } else {
      throw Exception('Failed to load lead statistics');
    }
  } on DioException catch (e) {
    throw Exception('Network error: ${e.message}');
  } catch (e) {
    throw Exception('Error loading statistics: $e');
  }
});