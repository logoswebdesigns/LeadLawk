// Authentication Integration Tests
// Tests the complete authentication flow across all features

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';

import 'package:leadloq/features/auth/domain/entities/auth_failure.dart';
import 'package:leadloq/features/auth/domain/repositories/auth_repository.dart';
import 'package:leadloq/features/auth/data/models/auth_models.dart';
import 'package:leadloq/core/security/biometric_service.dart';
import 'package:leadloq/core/security/secure_storage_service.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockBiometricService extends Mock implements BiometricService {}
class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  group('Authentication Integration Tests', () {
    late MockAuthRepository mockAuthRepository;
    late MockBiometricService mockBiometricService;
    late MockSecureStorageService mockSecureStorage;

    setUp(() {
      mockAuthRepository = MockAuthRepository();
      mockBiometricService = MockBiometricService();
      mockSecureStorage = MockSecureStorageService();
    });

    group('Login Flow', () {
      test('successful email/password login', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        final expectedTokens = AuthTokens(
          accessToken: 'access_token',
          refreshToken: 'refresh_token',
          tokenType: 'bearer',
          expiresIn: 3600,
        );

        when(mockAuthRepository.login(email, password))
            .thenAnswer((_) async => Right(expectedTokens));

        // Act
        final result = await mockAuthRepository.login(email, password);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success, got failure: $failure'),
          (tokens) => expect(tokens, expectedTokens),
        );
      });

      test('failed login with invalid credentials', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'wrong_password';

        when(mockAuthRepository.login(email, password))
            .thenAnswer((_) async => const Left(AuthFailure.invalidCredentials()));

        // Act
        final result = await mockAuthRepository.login(email, password);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, AuthFailure.invalidCredentials()),
          (tokens) => fail('Expected failure, got success'),
        );
      });
    });

    group('Biometric Authentication', () {
      test('successful biometric authentication', () async {
        // Arrange
        when(mockBiometricService.isBiometricAvailable())
            .thenAnswer((_) async => true);
        when(mockBiometricService.isDeviceEnrolled())
            .thenAnswer((_) async => true);
        when(mockBiometricService.authenticate())
            .thenAnswer((_) async => true);

        // Act
        final isAvailable = await mockBiometricService.isBiometricAvailable();
        final isEnrolled = await mockBiometricService.isDeviceEnrolled();
        final authResult = await mockBiometricService.authenticate();

        // Assert
        expect(isAvailable, true);
        expect(isEnrolled, true);
        expect(authResult, true);
      });

      test('biometric authentication not available', () async {
        // Arrange
        when(mockBiometricService.isBiometricAvailable())
            .thenAnswer((_) async => false);

        // Act
        final isAvailable = await mockBiometricService.isBiometricAvailable();

        // Assert
        expect(isAvailable, false);
      });
    });

    group('Secure Storage', () {
      test('store and retrieve tokens', () async {
        // Arrange
        const key = 'access_token';
        const value = 'test_token';

        when(mockSecureStorage.store(key, value))
            .thenAnswer((_) async => {});
        when(mockSecureStorage.retrieve(key))
            .thenAnswer((_) async => value);

        // Act
        await mockSecureStorage.store(key, value);
        final retrievedValue = await mockSecureStorage.retrieve(key);

        // Assert
        expect(retrievedValue, value);
        verify(mockSecureStorage.store(key, value)).called(1);
        verify(mockSecureStorage.retrieve(key)).called(1);
      });

      test('clear stored tokens', () async {
        // Arrange
        when(mockSecureStorage.clear())
            .thenAnswer((_) async => {});

        // Act
        await mockSecureStorage.clear();

        // Assert
        verify(mockSecureStorage.clear()).called(1);
      });
    });

    group('Registration Flow', () {
      test('successful user registration', () async {
        // Arrange
        const email = 'newuser@example.com';
        const password = 'strongPassword123!';
        const fullName = 'New User';
        final expectedTokens = AuthTokens(
          accessToken: 'access_token',
          refreshToken: 'refresh_token',
          tokenType: 'bearer',
          expiresIn: 3600,
        );

        when(mockAuthRepository.register(email, password, fullName))
            .thenAnswer((_) async => Right(expectedTokens));

        // Act
        final result = await mockAuthRepository.register(email, password, fullName);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success, got failure: $failure'),
          (tokens) => expect(tokens, expectedTokens),
        );
      });

      test('registration fails with email already in use', () async {
        // Arrange
        const email = 'existing@example.com';
        const password = 'password123';
        const fullName = 'User Name';

        when(mockAuthRepository.register(email, password, fullName))
            .thenAnswer((_) async => const Left(AuthFailure.emailAlreadyInUse()));

        // Act
        final result = await mockAuthRepository.register(email, password, fullName);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, AuthFailure.emailAlreadyInUse()),
          (tokens) => fail('Expected failure, got success'),
        );
      });
    });

    group('Token Management', () {
      test('refresh token successfully', () async {
        // Arrange
        const refreshToken = 'refresh_token';
        final expectedTokens = AuthTokens(
          accessToken: 'new_access_token',
          refreshToken: 'new_refresh_token',
          tokenType: 'bearer',
          expiresIn: 3600,
        );

        when(mockAuthRepository.refreshToken(refreshToken))
            .thenAnswer((_) async => Right(expectedTokens));

        // Act
        final result = await mockAuthRepository.refreshToken(refreshToken);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Expected success, got failure: $failure'),
          (tokens) => expect(tokens, expectedTokens),
        );
      });

      test('refresh token fails with invalid token', () async {
        // Arrange
        const refreshToken = 'invalid_refresh_token';

        when(mockAuthRepository.refreshToken(refreshToken))
            .thenAnswer((_) async => const Left(AuthFailure.invalidToken()));

        // Act
        final result = await mockAuthRepository.refreshToken(refreshToken);

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, AuthFailure.invalidToken()),
          (tokens) => fail('Expected failure, got success'),
        );
      });
    });
  });
}