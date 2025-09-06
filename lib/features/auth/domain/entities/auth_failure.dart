// Authentication Failure Entity.
// Pattern: Entity Pattern - represents authentication errors and failures.
// Single Responsibility: Authentication error representation.
// File size: <100 lines as per CLAUDE.md requirements.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_failure.freezed.dart';

@freezed
class AuthFailure with _$AuthFailure {
  const factory AuthFailure.serverError([String? message]) = _ServerError;
  const factory AuthFailure.networkError([String? message]) = _NetworkError;
  const factory AuthFailure.invalidCredentials([String? message]) = _InvalidCredentials;
  const factory AuthFailure.userNotFound([String? message]) = _UserNotFound;
  const factory AuthFailure.emailAlreadyInUse([String? message]) = _EmailAlreadyInUse;
  const factory AuthFailure.weakPassword([String? message]) = _WeakPassword;
  const factory AuthFailure.invalidEmail([String? message]) = _InvalidEmail;
  const factory AuthFailure.userDisabled([String? message]) = _UserDisabled;
  const factory AuthFailure.tooManyRequests([String? message]) = _TooManyRequests;
  const factory AuthFailure.operationNotAllowed([String? message]) = _OperationNotAllowed;
  const factory AuthFailure.invalidToken([String? message]) = _InvalidToken;
  const factory AuthFailure.tokenExpired([String? message]) = _TokenExpired;
  const factory AuthFailure.biometricNotAvailable([String? message]) = _BiometricNotAvailable;
  const factory AuthFailure.biometricNotEnrolled([String? message]) = _BiometricNotEnrolled;
  const factory AuthFailure.biometricFailed([String? message]) = _BiometricFailed;
  const factory AuthFailure.twoFactorRequired([String? message]) = _TwoFactorRequired;
  const factory AuthFailure.invalidTwoFactorCode([String? message]) = _InvalidTwoFactorCode;
  const factory AuthFailure.accountLocked([String? message]) = _AccountLocked;
  const factory AuthFailure.sessionExpired([String? message]) = _SessionExpired;
  const factory AuthFailure.deviceNotTrusted([String? message]) = _DeviceNotTrusted;
  const factory AuthFailure.emailNotVerified([String? message]) = _EmailNotVerified;
  const factory AuthFailure.socialLoginFailed(SocialAuthProvider provider, [String? message]) = _SocialLoginFailed;
  const factory AuthFailure.unknownError([String? message]) = _UnknownError;
}

enum SocialAuthProvider {
  google,
  apple,
  microsoft,
  github,
}

extension AuthFailureExtension on AuthFailure {
  String get message {
    return when(
      serverError: (msg) => msg ?? 'Server error occurred',
      networkError: (msg) => msg ?? 'Network connection failed',
      invalidCredentials: (msg) => msg ?? 'Invalid email or password',
      userNotFound: (msg) => msg ?? 'User not found',
      emailAlreadyInUse: (msg) => msg ?? 'Email is already registered',
      weakPassword: (msg) => msg ?? 'Password is too weak',
      invalidEmail: (msg) => msg ?? 'Invalid email format',
      userDisabled: (msg) => msg ?? 'This account has been disabled',
      tooManyRequests: (msg) => msg ?? 'Too many attempts. Please try again later',
      operationNotAllowed: (msg) => msg ?? 'This operation is not allowed',
      invalidToken: (msg) => msg ?? 'Invalid authentication token',
      tokenExpired: (msg) => msg ?? 'Authentication token has expired',
      biometricNotAvailable: (msg) => msg ?? 'Biometric authentication not available',
      biometricNotEnrolled: (msg) => msg ?? 'No biometric credentials enrolled',
      biometricFailed: (msg) => msg ?? 'Biometric authentication failed',
      twoFactorRequired: (msg) => msg ?? 'Two-factor authentication required',
      invalidTwoFactorCode: (msg) => msg ?? 'Invalid two-factor code',
      accountLocked: (msg) => msg ?? 'Account locked due to multiple failed attempts',
      sessionExpired: (msg) => msg ?? 'Session has expired. Please log in again',
      deviceNotTrusted: (msg) => msg ?? 'Device not trusted. Please verify your identity',
      emailNotVerified: (msg) => msg ?? 'Email address not verified',
      socialLoginFailed: (provider, msg) => msg ?? '${provider.name} login failed',
      unknownError: (msg) => msg ?? 'An unknown error occurred',
    );
  }

  bool get isRetryable {
    return when(
      serverError: (_) => true,
      networkError: (_) => true,
      invalidCredentials: (_) => false,
      userNotFound: (_) => false,
      emailAlreadyInUse: (_) => false,
      weakPassword: (_) => false,
      invalidEmail: (_) => false,
      userDisabled: (_) => false,
      tooManyRequests: (_) => true,
      operationNotAllowed: (_) => false,
      invalidToken: (_) => true,
      tokenExpired: (_) => true,
      biometricNotAvailable: (_) => false,
      biometricNotEnrolled: (_) => false,
      biometricFailed: (_) => true,
      twoFactorRequired: (_) => false,
      invalidTwoFactorCode: (_) => true,
      accountLocked: (_) => false,
      sessionExpired: (_) => true,
      deviceNotTrusted: (_) => false,
      emailNotVerified: (_) => false,
      socialLoginFailed: (_, __) => true,
      unknownError: (_) => true,
    );
  }
}