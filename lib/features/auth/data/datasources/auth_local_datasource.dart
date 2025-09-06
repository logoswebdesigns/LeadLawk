// Authentication Local Data Source.
// Pattern: Data Source Pattern - handles local storage operations.
// Single Responsibility: Local authentication data storage.
// File size: <100 lines as per CLAUDE.md requirements.

import 'dart:convert';
import '../../domain/entities/auth_user.dart';
import '../models/auth_models.dart';
import '../../../../core/security/secure_storage_service.dart';

abstract class AuthLocalDataSource {
  Future<void> storeTokens(AuthTokens tokens);
  Future<AuthTokens?> getStoredTokens();
  Future<void> clearTokens();
  Future<void> storeUser(AuthUser user);
  Future<AuthUser?> getStoredUser();
  Future<void> clearUser();
  Future<void> storeBiometricEnabled(bool enabled);
  Future<bool> isBiometricEnabled();
  Future<void> storeDeviceId(String deviceId);
  Future<String?> getDeviceId();
  Future<void> storeRememberDevice(bool remember);
  Future<bool> shouldRememberDevice();
  Future<void> storeTwoFactorEnabled(bool enabled);
  Future<bool> isTwoFactorEnabled();
  Future<void> storeSessionId(String sessionId);
  Future<String?> getSessionId();
  Future<void> clearAll();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SecureStorageService _secureStorage;

  AuthLocalDataSourceImpl({required SecureStorageService secureStorage}) 
    : _secureStorage = secureStorage;

  @override
  Future<void> storeTokens(AuthTokens tokens) async {
    await _secureStorage.store(AuthStorageKeys.accessToken, tokens.accessToken);
    await _secureStorage.store(AuthStorageKeys.refreshToken, tokens.refreshToken);
    
    // Store token metadata
    final metadata = {
      'token_type': tokens.tokenType,
      'expires_in': tokens.expiresIn,
      'issued_at': tokens.issuedAt?.toIso8601String(),
    };
    await _secureStorage.store('token_metadata', jsonEncode(metadata));
  }

  @override
  Future<AuthTokens?> getStoredTokens() async {
    final accessToken = await _secureStorage.retrieve(AuthStorageKeys.accessToken);
    final refreshToken = await _secureStorage.retrieve(AuthStorageKeys.refreshToken);
    
    if (accessToken == null || refreshToken == null) return null;
    
    try {
      final metadataString = await _secureStorage.retrieve('token_metadata');
      Map<String, dynamic> metadata = {};
      
      if (metadataString != null) {
        metadata = jsonDecode(metadataString);
      }
      
      return AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenType: metadata['token_type'] ?? 'bearer',
        expiresIn: metadata['expires_in'] ?? 3600,
        issuedAt: metadata['issued_at'] != null 
          ? DateTime.parse(metadata['issued_at']) 
          : null,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> clearTokens() async {
    await _secureStorage.delete(AuthStorageKeys.accessToken);
    await _secureStorage.delete(AuthStorageKeys.refreshToken);
    await _secureStorage.delete('token_metadata');
  }

  @override
  Future<void> storeUser(AuthUser user) async {
    await _secureStorage.store(AuthStorageKeys.userId, user.id);
    await _secureStorage.store(AuthStorageKeys.userEmail, user.email);
    await _secureStorage.store('user_data', jsonEncode(user.toJson()));
  }

  @override
  Future<AuthUser?> getStoredUser() async {
    try {
      final userData = await _secureStorage.retrieve('user_data');
      if (userData == null) return null;
      
      final json = jsonDecode(userData);
      return AuthUser.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> clearUser() async {
    await _secureStorage.delete(AuthStorageKeys.userId);
    await _secureStorage.delete(AuthStorageKeys.userEmail);
    await _secureStorage.delete('user_data');
  }

  @override
  Future<void> storeBiometricEnabled(bool enabled) async {
    await _secureStorage.store(AuthStorageKeys.biometricEnabled, enabled.toString());
  }

  @override
  Future<bool> isBiometricEnabled() async {
    final enabled = await _secureStorage.retrieve(AuthStorageKeys.biometricEnabled);
    return enabled == 'true';
  }

  @override
  Future<void> storeDeviceId(String deviceId) async {
    await _secureStorage.store(AuthStorageKeys.deviceId, deviceId);
  }

  @override
  Future<String?> getDeviceId() async {
    return await _secureStorage.retrieve(AuthStorageKeys.deviceId);
  }

  @override
  Future<void> storeRememberDevice(bool remember) async {
    await _secureStorage.store(AuthStorageKeys.rememberDevice, remember.toString());
  }

  @override
  Future<bool> shouldRememberDevice() async {
    final remember = await _secureStorage.retrieve(AuthStorageKeys.rememberDevice);
    return remember == 'true';
  }

  @override
  Future<void> storeTwoFactorEnabled(bool enabled) async {
    await _secureStorage.store(AuthStorageKeys.twoFactorEnabled, enabled.toString());
  }

  @override
  Future<bool> isTwoFactorEnabled() async {
    final enabled = await _secureStorage.retrieve(AuthStorageKeys.twoFactorEnabled);
    return enabled == 'true';
  }

  @override
  Future<void> storeSessionId(String sessionId) async {
    await _secureStorage.store(AuthStorageKeys.sessionId, sessionId);
  }

  @override
  Future<String?> getSessionId() async {
    return await _secureStorage.retrieve(AuthStorageKeys.sessionId);
  }

  @override
  Future<void> clearAll() async {
    await _secureStorage.clear();
  }
}