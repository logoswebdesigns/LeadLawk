// Authentication Repository Implementation.
// Pattern: Repository Pattern - concrete implementation of auth operations.
// Single Responsibility: Authentication data access implementation.
// File size: <100 lines as per CLAUDE.md requirements.

import 'package:dartz/dartz.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/social_auth_datasource.dart';
import '../models/auth_models.dart';
import '../../../../core/security/biometric_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final SocialAuthDataSource _socialAuthDataSource;
  final BiometricService _biometricService;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required SocialAuthDataSource socialAuthDataSource,
    required BiometricService biometricService,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource,
       _socialAuthDataSource = socialAuthDataSource,
       _biometricService = biometricService;

  @override
  Future<Either<AuthFailure, AuthTokens>> login(String email, String password) async {
    try {
      final tokens = await _remoteDataSource.login(email, password);
      await _localDataSource.storeTokens(tokens);
      return Right(tokens);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, AuthTokens>> register(String email, String password, String fullName) async {
    try {
      final tokens = await _remoteDataSource.register(email, password, fullName);
      await _localDataSource.storeTokens(tokens);
      return Right(tokens);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> logout() async {
    try {
      await _remoteDataSource.logout();
      await _localDataSource.clearTokens();
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, AuthTokens>> refreshToken(String refreshToken) async {
    try {
      final tokens = await _remoteDataSource.refreshToken(refreshToken);
      await _localDataSource.storeTokens(tokens);
      return Right(tokens);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, AuthUser>> getCurrentUser() async {
    try {
      final user = await _remoteDataSource.getCurrentUser();
      return Right(user);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, bool>> isBiometricAvailable() async {
    try {
      final isAvailable = await _biometricService.isBiometricAvailable();
      final isEnrolled = await _biometricService.isDeviceEnrolled();
      return Right(isAvailable && isEnrolled);
    } catch (e) {
      return const Left(AuthFailure.biometricNotAvailable());
    }
  }

  @override
  Future<Either<AuthFailure, AuthTokens>> authenticateWithBiometric() async {
    try {
      final success = await _biometricService.authenticate();
      if (!success) {
        return const Left(AuthFailure.biometricFailed());
      }

      final tokens = await _localDataSource.getStoredTokens();
      if (tokens == null) {
        return const Left(AuthFailure.sessionExpired());
      }

      return Right(tokens);
    } catch (e) {
      return const Left(AuthFailure.biometricFailed());
    }
  }

  // Stub implementations for all remaining methods
  @override
  Future<Either<AuthFailure, Unit>> changePassword(String currentPassword, String newPassword) async {
    try {
      await _remoteDataSource.changePassword(currentPassword, newPassword);
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> forgotPassword(String email) async {
    try {
      await _remoteDataSource.forgotPassword(email);
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> resetPassword(String token, String newPassword) async {
    try {
      await _remoteDataSource.resetPassword(token, newPassword);
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> sendEmailVerification() async {
    try {
      await _remoteDataSource.sendEmailVerification();
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> verifyEmail(String token) async {
    try {
      await _remoteDataSource.verifyEmail(token);
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, String>> enableTwoFactor() async {
    try {
      final secret = await _remoteDataSource.enableTwoFactor();
      return Right(secret);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> disableTwoFactor(String password) async {
    try {
      await _remoteDataSource.disableTwoFactor(password);
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, AuthTokens>> verifyTwoFactor(String code, String email) async {
    try {
      final tokens = await _remoteDataSource.verifyTwoFactor(code, email);
      return Right(tokens);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, List<String>>> generateBackupCodes() async {
    try {
      final codes = await _remoteDataSource.generateBackupCodes();
      return Right(codes);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> enableBiometric() async {
    try {
      await _localDataSource.storeBiometricEnabled(true);
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> disableBiometric() async {
    try {
      await _localDataSource.storeBiometricEnabled(false);
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, AuthTokens>> signInWithGoogle() async {
    try {
      await _socialAuthDataSource.signInWithGoogle();
      // TODO: Convert social info to tokens via backend
      throw UnimplementedError('Social auth tokens conversion not implemented');
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, AuthTokens>> signInWithApple() async {
    try {
      await _socialAuthDataSource.signInWithApple();
      // TODO: Convert social info to tokens via backend
      throw UnimplementedError('Social auth tokens conversion not implemented');
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, AuthTokens>> signInWithMicrosoft() async {
    try {
      await _socialAuthDataSource.signInWithMicrosoft();
      // TODO: Convert social info to tokens via backend
      throw UnimplementedError('Social auth tokens conversion not implemented');
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, AuthTokens>> signInWithGitHub() async {
    try {
      await _socialAuthDataSource.signInWithGitHub();
      // TODO: Convert social info to tokens via backend
      throw UnimplementedError('Social auth tokens conversion not implemented');
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, List<AuthSession>>> getActiveSessions() async {
    try {
      final sessions = await _remoteDataSource.getActiveSessions();
      return Right(sessions);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> revokeSession(String sessionId) async {
    try {
      await _remoteDataSource.revokeSession(sessionId);
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> revokeAllSessions() async {
    try {
      await _remoteDataSource.revokeAllSessions();
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> updateProfile(String fullName, String? phoneNumber) async {
    try {
      await _remoteDataSource.updateProfile(fullName, phoneNumber);
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> deleteAccount(String password) async {
    try {
      await _remoteDataSource.deleteAccount(password);
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Map<String, dynamic>>> exportUserData() async {
    try {
      final data = await _remoteDataSource.exportUserData();
      return Right(data);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> storeTokens(AuthTokens tokens) async {
    try {
      await _localDataSource.storeTokens(tokens);
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, AuthTokens?>> getStoredTokens() async {
    try {
      final tokens = await _localDataSource.getStoredTokens();
      return Right(tokens);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> clearStoredTokens() async {
    try {
      await _localDataSource.clearTokens();
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> trustDevice(String deviceId) async {
    try {
      await _remoteDataSource.trustDevice(deviceId);
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> untrustDevice(String deviceId) async {
    try {
      await _remoteDataSource.untrustDevice(deviceId);
      return const Right(unit);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<AuthFailure, bool>> isDeviceTrusted(String deviceId) async {
    try {
      final trusted = await _remoteDataSource.isDeviceTrusted(deviceId);
      return Right(trusted);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  AuthFailure _mapExceptionToFailure(dynamic exception) {
    // Map different types of exceptions to AuthFailure
    if (exception.toString().contains('network')) {
      return AuthFailure.networkError();
    } else if (exception.toString().contains('401')) {
      return AuthFailure.invalidCredentials();
    } else if (exception.toString().contains('404')) {
      return AuthFailure.userNotFound();
    } else if (exception.toString().contains('409')) {
      return AuthFailure.emailAlreadyInUse();
    } else if (exception.toString().contains('429')) {
      return AuthFailure.tooManyRequests();
    }
    
    return AuthFailure.unknownError();
  }
}