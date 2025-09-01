import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lead.dart';
import '../../data/datasources/leads_remote_datasource.dart';
import 'package:dio/dio.dart';

// Sales pitch entity
class SalesPitch {
  final String id;
  final String name;
  final String content;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int conversions;
  final int attempts;
  final double conversionRate;

  SalesPitch({
    required this.id,
    required this.name,
    required this.content,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.conversions,
    required this.attempts,
    required this.conversionRate,
  });

  factory SalesPitch.fromJson(Map<String, dynamic> json) {
    return SalesPitch(
      id: json['id'],
      name: json['name'],
      content: json['content'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      conversions: json['conversions'] ?? 0,
      attempts: json['attempts'] ?? 0,
      conversionRate: (json['conversion_rate'] ?? 0.0).toDouble(),
    );
  }
}

// Data source provider
final salesPitchDataSourceProvider = Provider<SalesPitchDataSource>((ref) {
  return SalesPitchDataSource();
});

// Sales pitches provider
final salesPitchesProvider = FutureProvider<List<SalesPitch>>((ref) async {
  final dataSource = ref.watch(salesPitchDataSourceProvider);
  return dataSource.getSalesPitches();
});

// Selected pitch provider for a specific lead
final selectedPitchProvider = StateProvider.family<String?, String>((ref, leadId) {
  return null;
});

// Data source for sales pitch API calls
class SalesPitchDataSource {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<List<SalesPitch>> getSalesPitches() async {
    try {
      final response = await dio.get('/sales-pitches');
      final List<dynamic> data = response.data;
      return data.map((json) => SalesPitch.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load sales pitches: $e');
    }
  }

  Future<void> assignPitchToLead(String leadId, String pitchId) async {
    try {
      await dio.post('/leads/$leadId/assign-pitch', data: {
        'sales_pitch_id': pitchId,
      });
    } catch (e) {
      throw Exception('Failed to assign pitch to lead: $e');
    }
  }

  Future<SalesPitch> createSalesPitch({
    required String name,
    required String content,
  }) async {
    try {
      final response = await dio.post('/sales-pitches', data: {
        'name': name,
        'content': content,
        'is_active': true,
      });
      return SalesPitch.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create sales pitch: $e');
    }
  }

  Future<void> updateSalesPitch(String id, {
    String? name,
    String? content,
    bool? isActive,
  }) async {
    try {
      await dio.put('/sales-pitches/$id', data: {
        if (name != null) 'name': name,
        if (content != null) 'content': content,
        if (isActive != null) 'is_active': isActive,
      });
    } catch (e) {
      throw Exception('Failed to update sales pitch: $e');
    }
  }

  Future<void> deleteSalesPitch(String id) async {
    try {
      await dio.delete('/sales-pitches/$id');
    } catch (e) {
      throw Exception('Failed to delete sales pitch: $e');
    }
  }

  Future<Map<String, dynamic>> getSalesPitchAnalytics() async {
    try {
      final response = await dio.get('/sales-pitches/analytics');
      return response.data;
    } catch (e) {
      throw Exception('Failed to get sales pitch analytics: $e');
    }
  }
}