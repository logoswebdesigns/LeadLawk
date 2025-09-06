import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/entities/lead.dart';
import '../../../../core/utils/debug_logger.dart';

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
      // Safely cast the dynamic map to Map<String, dynamic>
      final byStatusData = Map<String, dynamic>.from(json['by_status'] as Map);
      byStatusData.forEach((key, value) {
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
            DebugLogger.log('⚠️ Unknown status key: $key with value: $value');
            return; // Skip this iteration
        }
        byStatusMap[status] = value as int;
        DebugLogger.log('📊 Mapped $key -> $status = $value');
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
      DebugLogger.log('📊 Final: $status = $count');
    });
    DebugLogger.network('📊 Total from API: ${stats.total}, Sum of stages: $sum');
    
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
  
  // Add timeout to prevent blocking forever
  dio.options.connectTimeout = const Duration(seconds: 5);
  dio.options.receiveTimeout = const Duration(seconds: 10);
  
  try {
    DebugLogger.log('📊 Fetching lead statistics from $baseUrl/leads/statistics/all');
    
    // Add explicit timeout to the request
    final response = await dio.get(
      '$baseUrl/leads/statistics/all',
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        DebugLogger.network('📊 Statistics request timed out after 10 seconds');
        // Return empty statistics on timeout rather than throwing
        return Response(
          requestOptions: RequestOptions(path: ''),
          data: {
            'total': 0,
            'by_status': {},
            'conversion_rate': 0.0,
          },
          statusCode: 200,
        );
      },
    );
    
    if (response.statusCode == 200) {
      // Safely cast response.data to Map<String, dynamic>
      final data = Map<String, dynamic>.from(response.data as Map);
      final stats = LeadStatistics.fromJson(data);
      DebugLogger.log('📊 Statistics loaded: ${stats.total} total leads');
      return stats;
    } else {
      throw Exception('Failed to load lead statistics');
    }
  } on DioException catch (e) {
    DebugLogger.network('📊 Network error loading statistics: ${e.message}');
    // Return empty statistics on error rather than crashing
    return LeadStatistics(
      total: 0,
      byStatus: {},
      conversionRate: 0.0,
    );
  } catch (e) {
    DebugLogger.error('📊 Error loading statistics: $e');
    // Return empty statistics on error rather than crashing
    return LeadStatistics(
      total: 0,
      byStatus: {},
      conversionRate: 0.0,
    );
  }
});