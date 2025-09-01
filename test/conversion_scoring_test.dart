import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:leadloq/features/leads/data/datasources/leads_remote_datasource.dart';

void main() {
  group('Conversion Scoring API Tests', () {
    late LeadsRemoteDataSource dataSource;
    late Dio dio;

    setUp(() {
      dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      dataSource = LeadsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://localhost:8000',
      );
    });

    test('recalculateConversionScores should handle successful response', () async {
      try {
        final result = await dataSource.recalculateConversionScores();
        expect(result, isA<Map<String, dynamic>>());
        expect(result['status'], isNotNull);
        expect(result['total_leads'], isNotNull);
        
        print('✅ Conversion scoring API call successful');
        print('   Status: ${result['status']}');
        print('   Total leads: ${result['total_leads']}');
        print('   Message: ${result['message']}');
      } catch (e) {
        print('❌ Error calling conversion scoring API: $e');
        // This test helps us understand what error Flutter is seeing
        fail('API call failed: $e');
      }
    });

    test('should provide meaningful error when server is down', () async {
      // Test with invalid URL to simulate server down
      final testDataSource = LeadsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://localhost:9999', // Invalid port
      );

      try {
        await testDataSource.recalculateConversionScores();
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e.toString(), contains('Connection error'));
        print('✅ Properly handles connection errors');
      }
    });
  });
}