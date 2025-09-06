// Authentication Models for Data Transfer Objects.
// Pattern: DTO Pattern - data transfer objects for API communication.
// Single Responsibility: Authentication data serialization/deserialization.
// File size: <100 lines as per CLAUDE.md requirements.

import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/auth_failure.dart';

part 'auth_models.freezed.dart';
part 'auth_models.g.dart';

@freezed
class AuthTokens with _$AuthTokens {
  const factory AuthTokens({
    required String accessToken,
    required String refreshToken,
    required String tokenType,
    required int expiresIn,
    DateTime? issuedAt,
  }) = _AuthTokens;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => _$AuthTokensFromJson(json);
}

@freezed
class AuthSession with _$AuthSession {
  const factory AuthSession({
    required String id,
    required String userId,
    required String deviceId,
    required String deviceName,
    required String platform,
    required DateTime createdAt,
    required DateTime lastActiveAt,
    required bool isActive,
    String? ipAddress,
    String? location,
  }) = _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) => _$AuthSessionFromJson(json);
}

@freezed
class SocialAuthInfo with _$SocialAuthInfo {
  const factory SocialAuthInfo({
    required SocialAuthProvider provider,
    required String providerId,
    String? accessToken,
    String? refreshToken,
    Map<String, dynamic>? metadata,
  }) = _SocialAuthInfo;

  factory SocialAuthInfo.fromJson(Map<String, dynamic> json) => _$SocialAuthInfoFromJson(json);
}

@freezed
class LoginRequest with _$LoginRequest {
  const factory LoginRequest({
    required String email,
    required String password,
    String? deviceId,
  }) = _LoginRequest;

  factory LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);
}

@freezed
class RegisterRequest with _$RegisterRequest {
  const factory RegisterRequest({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) = _RegisterRequest;

  factory RegisterRequest.fromJson(Map<String, dynamic> json) => _$RegisterRequestFromJson(json);
}