// Authentication Repository Interface.
// Pattern: Repository Pattern - abstraction for authentication operations.
// Single Responsibility: Authentication data access interface.
// File size: <100 lines as per CLAUDE.md requirements.

import 'package:dartz/dartz.dart';
import '../entities/auth_user.dart';
import '../entities/auth_failure.dart';
import '../../data/models/auth_models.dart';

abstract class AuthRepository {
  // Basic Authentication
  Future<Either<AuthFailure, AuthTokens>> login(String email, String password);
  Future<Either<AuthFailure, AuthTokens>> register(String email, String password, String fullName);
  Future<Either<AuthFailure, Unit>> logout();
  Future<Either<AuthFailure, AuthTokens>> refreshToken(String refreshToken);
  Future<Either<AuthFailure, AuthUser>> getCurrentUser();

  // Password Management
  Future<Either<AuthFailure, Unit>> changePassword(String currentPassword, String newPassword);
  Future<Either<AuthFailure, Unit>> forgotPassword(String email);
  Future<Either<AuthFailure, Unit>> resetPassword(String token, String newPassword);

  // Email Verification
  Future<Either<AuthFailure, Unit>> sendEmailVerification();
  Future<Either<AuthFailure, Unit>> verifyEmail(String token);

  // Two-Factor Authentication
  Future<Either<AuthFailure, String>> enableTwoFactor();
  Future<Either<AuthFailure, Unit>> disableTwoFactor(String password);
  Future<Either<AuthFailure, AuthTokens>> verifyTwoFactor(String code, String email);
  Future<Either<AuthFailure, List<String>>> generateBackupCodes();

  // Biometric Authentication
  Future<Either<AuthFailure, bool>> isBiometricAvailable();
  Future<Either<AuthFailure, Unit>> enableBiometric();
  Future<Either<AuthFailure, Unit>> disableBiometric();
  Future<Either<AuthFailure, AuthTokens>> authenticateWithBiometric();

  // Social Authentication
  Future<Either<AuthFailure, AuthTokens>> signInWithGoogle();
  Future<Either<AuthFailure, AuthTokens>> signInWithApple();
  Future<Either<AuthFailure, AuthTokens>> signInWithMicrosoft();
  Future<Either<AuthFailure, AuthTokens>> signInWithGitHub();

  // Session Management
  Future<Either<AuthFailure, List<AuthSession>>> getActiveSessions();
  Future<Either<AuthFailure, Unit>> revokeSession(String sessionId);
  Future<Either<AuthFailure, Unit>> revokeAllSessions();

  // Account Management
  Future<Either<AuthFailure, Unit>> updateProfile(String fullName, String? phoneNumber);
  Future<Either<AuthFailure, Unit>> deleteAccount(String password);
  Future<Either<AuthFailure, Map<String, dynamic>>> exportUserData();

  // Token Storage
  Future<Either<AuthFailure, Unit>> storeTokens(AuthTokens tokens);
  Future<Either<AuthFailure, AuthTokens?>> getStoredTokens();
  Future<Either<AuthFailure, Unit>> clearStoredTokens();

  // Device Management
  Future<Either<AuthFailure, Unit>> trustDevice(String deviceId);
  Future<Either<AuthFailure, Unit>> untrustDevice(String deviceId);
  Future<Either<AuthFailure, bool>> isDeviceTrusted(String deviceId);
}