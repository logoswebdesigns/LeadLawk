import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/core/repositories/base_repository.dart';
import 'package:leadloq/core/repositories/cache_manager.dart';
import 'package:leadloq/core/error/failures.dart';

void main() {
  group('Repository Pattern Implementation Tests', () {
    test('RepositoryConfig has correct default values', () {
      // Arrange & Act
      const config = RepositoryConfig();

      // Assert
      expect(config.cacheTimeout, equals(Duration(minutes: 5)));
      expect(config.maxRetries, equals(5));
      expect(config.initialRetryDelay, equals(Duration(seconds: 1)));
      expect(config.circuitBreakerThreshold, equals(5));
      expect(config.circuitBreakerResetTimeout, equals(Duration(seconds: 30)));
      expect(config.enablePersistentCache, isTrue);
      expect(config.enableNetworkCache, isTrue);
    });

    test('RepositoryConfig allows customization', () {
      // Arrange & Act
      const config = RepositoryConfig(
        cacheTimeout: Duration(minutes: 10),
        maxRetries: 3,
        initialRetryDelay: Duration(seconds: 2),
        circuitBreakerThreshold: 10,
        circuitBreakerResetTimeout: Duration(seconds: 60),
        enablePersistentCache: false,
        enableNetworkCache: true,
      );

      // Assert
      expect(config.cacheTimeout, equals(Duration(minutes: 10)));
      expect(config.maxRetries, equals(3));
      expect(config.initialRetryDelay, equals(Duration(seconds: 2)));
      expect(config.circuitBreakerThreshold, equals(10));
      expect(config.circuitBreakerResetTimeout, equals(Duration(seconds: 60)));
      expect(config.enablePersistentCache, isFalse);
      expect(config.enableNetworkCache, isTrue);
    });

    test('CacheManager singleton works correctly', () {
      // Arrange & Act
      final instance1 = CacheManager.instance;
      final instance2 = CacheManager.instance;

      // Assert
      expect(identical(instance1, instance2), isTrue);
    });

    test('All Failure types are properly defined with correct inheritance', () {
      // Arrange & Act
      const serverFailure = ServerFailure('Server error');
      const cacheFailure = CacheFailure('Cache error');
      const networkFailure = NetworkFailure('Network error');
      const validationFailure = ValidationFailure('Validation error');
      const processingFailure = ProcessingFailure('Processing error');
      const timeoutFailure = TimeoutFailure('Timeout error');
      const authFailure = AuthenticationFailure('Auth error');
      const permissionFailure = PermissionFailure('Permission error');
      const circuitBreakerFailure = CircuitBreakerFailure('Circuit breaker error');
      const dataConsistencyFailure = DataConsistencyFailure('Data error');

      // Assert types
      expect(serverFailure, isA<Failure>());
      expect(cacheFailure, isA<Failure>());
      expect(networkFailure, isA<Failure>());
      expect(validationFailure, isA<Failure>());
      expect(processingFailure, isA<Failure>());
      expect(timeoutFailure, isA<Failure>());
      expect(authFailure, isA<Failure>());
      expect(permissionFailure, isA<Failure>());
      expect(circuitBreakerFailure, isA<Failure>());
      expect(dataConsistencyFailure, isA<Failure>());

      // Assert messages
      expect(serverFailure.message, equals('Server error'));
      expect(cacheFailure.message, equals('Cache error'));
      expect(networkFailure.message, equals('Network error'));
      expect(validationFailure.message, equals('Validation error'));
      expect(processingFailure.message, equals('Processing error'));
      expect(timeoutFailure.message, equals('Timeout error'));
      expect(authFailure.message, equals('Auth error'));
      expect(permissionFailure.message, equals('Permission error'));
      expect(circuitBreakerFailure.message, equals('Circuit breaker error'));
      expect(dataConsistencyFailure.message, equals('Data error'));

      // Assert equatable behavior
      expect(serverFailure.props, equals(['Server error']));
      expect(cacheFailure.props, equals(['Cache error']));
    });

    test('Cache manager basic operations work without initialization', () {
      // Arrange
      final cacheManager = CacheManager.instance;
      const testKey = 'test_key_basic';
      const testValue = 'test_value_basic';

      // Act & Assert - should handle gracefully even without init
      expect(() async {
        await cacheManager.set(testKey, testValue, Duration(minutes: 1));
        final cached = cacheManager.get<String>(testKey);
        expect(cached, equals(testValue));
      }, returnsNormally);
    });

    test('Cache manager handles cache expiry correctly', () async {
      // Arrange
      final cacheManager = CacheManager.instance;
      const testKey = 'test_key_expire';
      const testValue = 'test_value_expire';

      // Act
      await cacheManager.set(testKey, testValue, Duration.zero);
      await Future.delayed(Duration(milliseconds: 10));
      final cached = cacheManager.get<String>(testKey);

      // Assert
      expect(cached, isNull);
    });

    test('Cache manager prefix removal works', () async {
      // Arrange
      final cacheManager = CacheManager.instance;
      const prefix = 'test_prefix';

      // Act
      await cacheManager.set('${prefix}_key1', 'value1', Duration(minutes: 1));
      await cacheManager.set('${prefix}_key2', 'value2', Duration(minutes: 1));
      await cacheManager.set('other_key', 'other_value', Duration(minutes: 1));

      await cacheManager.removeByPrefix(prefix);

      // Assert
      expect(cacheManager.get('${prefix}_key1'), isNull);
      expect(cacheManager.get('${prefix}_key2'), isNull);
      expect(cacheManager.get('other_key'), equals('other_value'));
    });

    test('Cache manager stats are accessible', () {
      // Arrange
      final cacheManager = CacheManager.instance;

      // Act
      final stats = cacheManager.getStats();

      // Assert
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('memory_entries'), isTrue);
      expect(stats.containsKey('persistent_entries'), isTrue);
      expect(stats.containsKey('memory_size_bytes'), isTrue);
    });
  });
}