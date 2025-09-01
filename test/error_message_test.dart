import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/data/repositories/leads_repository_impl.dart';
import 'package:leadloq/features/leads/data/datasources/leads_remote_datasource.dart';
import 'package:mocktail/mocktail.dart';

class MockLeadsRemoteDataSource extends Mock implements LeadsRemoteDataSource {}

void main() {
  group('Error Message Formatting Tests', () {
    late LeadsRepositoryImpl repository;
    late MockLeadsRemoteDataSource mockDataSource;

    setUp(() {
      mockDataSource = MockLeadsRemoteDataSource();
      repository = LeadsRepositoryImpl(remoteDataSource: mockDataSource);
    });

    test('should clean up Exception prefix from error messages', () async {
      // Simulate what happens when datasource throws an exception
      when(() => mockDataSource.recalculateConversionScores())
          .thenThrow(Exception('Connection error - check if server is running'));

      final result = await repository.recalculateConversionScores();

      result.fold(
        (failure) {
          // The error message should NOT contain "Exception: " prefix
          expect(failure.message, equals('Connection error - check if server is running'));
          expect(failure.message, isNot(contains('Exception:')));
          print('✅ Error message properly cleaned: ${failure.message}');
        },
        (_) => fail('Should have returned failure'),
      );
    });

    test('should handle DioException-style messages', () async {
      when(() => mockDataSource.recalculateConversionScores())
          .thenThrow(Exception('Network error: DioException [connection timeout]'));

      final result = await repository.recalculateConversionScores();

      result.fold(
        (failure) {
          expect(failure.message, equals('Network error: DioException [connection timeout]'));
          expect(failure.message, isNot(startsWith('Exception:')));
          print('✅ DioException message properly handled: ${failure.message}');
        },
        (_) => fail('Should have returned failure'),
      );
    });

    test('should handle server error messages', () async {
      when(() => mockDataSource.recalculateConversionScores())
          .thenThrow(Exception('Server error: 500 - Internal Server Error'));

      final result = await repository.recalculateConversionScores();

      result.fold(
        (failure) {
          expect(failure.message, equals('Server error: 500 - Internal Server Error'));
          print('✅ Server error message properly formatted: ${failure.message}');
        },
        (_) => fail('Should have returned failure'),
      );
    });
  });
}