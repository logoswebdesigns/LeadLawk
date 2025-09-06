// Secure Storage Service.
// Pattern: Service Pattern - secure storage operations.
// Single Responsibility: Secure data storage management.
// File size: <100 lines as per CLAUDE.md requirements.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStorageService {
  Future<void> store(String key, String value);
  Future<String?> retrieve(String key);
  Future<void> delete(String key);
  Future<void> clear();
}

class SecureStorageServiceImpl implements SecureStorageService {
  static const _storage = FlutterSecureStorage();

  @override
  Future<void> store(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<String?> retrieve(String key) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  @override
  Future<void> clear() async {
    await _storage.deleteAll();
  }
}

class AuthStorageKeys {
  static const String accessToken = 'auth_access_token';
  static const String refreshToken = 'auth_refresh_token';
  static const String userId = 'auth_user_id';
  static const String userEmail = 'auth_user_email';
  static const String biometricEnabled = 'auth_biometric_enabled';
  static const String deviceId = 'auth_device_id';
  static const String rememberDevice = 'auth_remember_device';
  static const String twoFactorEnabled = 'auth_two_factor_enabled';
  static const String sessionId = 'auth_session_id';
}