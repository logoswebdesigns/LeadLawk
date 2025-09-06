// Authentication Remote Data Source.
// Pattern: Data Source Pattern - handles remote API communication.
// Single Responsibility: Remote authentication API communication.

import 'package:dio/dio.dart';
import '../../domain/entities/auth_user.dart';
import '../models/auth_models.dart';
import '../../../../core/network/api_client.dart';

abstract class AuthRemoteDataSource {
  Future<AuthTokens> login(String email, String password);
  Future<AuthTokens> register(String email, String password, String fullName);
  Future<void> logout();
  Future<AuthTokens> refreshToken(String refreshToken);
  Future<AuthUser> getCurrentUser();
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(String token, String newPassword);
  Future<void> sendEmailVerification();
  Future<void> verifyEmail(String token);
  Future<String> enableTwoFactor();
  Future<void> disableTwoFactor(String password);
  Future<AuthTokens> verifyTwoFactor(String code, String email);
  Future<List<String>> generateBackupCodes();
  Future<List<AuthSession>> getActiveSessions();
  Future<void> revokeSession(String sessionId);
  Future<void> revokeAllSessions();
  Future<void> updateProfile(String fullName, String? phoneNumber);
  Future<void> deleteAccount(String password);
  Future<Map<String, dynamic>> exportUserData();
  Future<void> trustDevice(String deviceId);
  Future<void> untrustDevice(String deviceId);
  Future<bool> isDeviceTrusted(String deviceId);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<AuthTokens> login(String email, String password) async {
    try {
      final response = await _apiClient.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      return AuthTokens.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthTokens> register(String email, String password, String fullName) async {
    try {
      final response = await _apiClient.post('/auth/register', data: {
        'email': email,
        'password': password,
        'full_name': fullName,
      });
      return AuthTokens.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthTokens> refreshToken(String refreshToken) async {
    try {
      final response = await _apiClient.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      return AuthTokens.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthUser> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/auth/me');
      return AuthUser.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      await _apiClient.put('/auth/password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Stub implementations for all remaining methods
  @override
  Future<void> forgotPassword(String email) async {
    await _apiClient.post('/auth/forgot-password', data: {'email': email});
  }

  @override
  Future<void> resetPassword(String token, String newPassword) async {
    await _apiClient.post('/auth/reset-password', data: {'token': token, 'new_password': newPassword});
  }

  @override
  Future<void> sendEmailVerification() async {
    await _apiClient.post('/auth/send-verification');
  }

  @override
  Future<void> verifyEmail(String token) async {
    await _apiClient.post('/auth/verify-email', data: {'token': token});
  }

  @override
  Future<String> enableTwoFactor() async {
    final response = await _apiClient.post('/auth/2fa/enable');
    return response.data['secret'] ?? '';
  }

  @override
  Future<void> disableTwoFactor(String password) async {
    await _apiClient.post('/auth/2fa/disable', data: {'password': password});
  }

  @override
  Future<AuthTokens> verifyTwoFactor(String code, String email) async {
    final response = await _apiClient.post('/auth/2fa/verify', data: {'code': code, 'email': email});
    return AuthTokens.fromJson(response.data);
  }

  @override
  Future<List<String>> generateBackupCodes() async {
    final response = await _apiClient.post('/auth/2fa/backup-codes');
    return List<String>.from(response.data['codes'] ?? []);
  }

  @override
  Future<List<AuthSession>> getActiveSessions() async {
    final response = await _apiClient.get('/auth/sessions');
    return (response.data['sessions'] as List? ?? [])
        .map((json) => AuthSession.fromJson(json))
        .toList();
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    await _apiClient.delete('/auth/sessions/$sessionId');
  }

  @override
  Future<void> revokeAllSessions() async {
    await _apiClient.delete('/auth/sessions');
  }

  @override
  Future<void> updateProfile(String fullName, String? phoneNumber) async {
    await _apiClient.put('/auth/profile', data: {
      'full_name': fullName,
      if (phoneNumber != null) 'phone_number': phoneNumber,
    });
  }

  @override
  Future<void> deleteAccount(String password) async {
    await _apiClient.delete('/auth/account', data: {'password': password});
  }

  @override
  Future<Map<String, dynamic>> exportUserData() async {
    final response = await _apiClient.get('/auth/export-data');
    return response.data;
  }

  @override
  Future<void> trustDevice(String deviceId) async {
    await _apiClient.post('/auth/devices/trust', data: {'device_id': deviceId});
  }

  @override
  Future<void> untrustDevice(String deviceId) async {
    await _apiClient.delete('/auth/devices/trust', data: {'device_id': deviceId});
  }

  @override
  Future<bool> isDeviceTrusted(String deviceId) async {
    final response = await _apiClient.get('/auth/devices/trust', queryParameters: {'device_id': deviceId});
    return response.data['trusted'] ?? false;
  }

  Exception _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return Exception('Network error: ${error.message}');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        final message = error.response?.data?['message'] ?? 'Unknown error';
        return Exception('HTTP $statusCode: $message');
      default:
        return Exception('Unknown error: ${error.message}');
    }
  }
}