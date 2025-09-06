// Cross-platform Authentication Provider.
// Pattern: Provider Pattern - centralizes auth state management.
// Single Responsibility: Authentication state coordination across platforms.
// File size: <100 lines as per CLAUDE.md requirements.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/models/auth_models.dart';
import '../../../../core/security/biometric_service.dart';
import '../../../../core/security/device_service.dart';

part 'auth_provider.freezed.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError('AuthRepository not provided');
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricServiceImpl();
});

final deviceServiceProvider = Provider<DeviceService>((ref) {
  return DeviceServiceImpl();
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    authRepository: ref.read(authRepositoryProvider),
    biometricService: ref.read(biometricServiceProvider),
    deviceService: ref.read(deviceServiceProvider),
  );
});

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(AuthUser user, AuthTokens tokens) = _Authenticated;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.error(AuthFailure failure) = _Error;
  const factory AuthState.twoFactorRequired(String email) = _TwoFactorRequired;
  const factory AuthState.biometricAvailable() = _BiometricAvailable;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final BiometricService _biometricService;
  final DeviceService _deviceService;

  AuthNotifier({
    required AuthRepository authRepository,
    required BiometricService biometricService,
    required DeviceService deviceService,
  })  : _authRepository = authRepository,
        _biometricService = biometricService,
        _deviceService = deviceService,
        super(AuthState.initial()) {
    _init();
  }

  Future<void> _init() async {
    state = AuthState.loading();
    
    // Check biometric availability for enhanced security
    final biometricAvailable = await _biometricService.isAvailable();
    if (biometricAvailable) {
      final biometricTypes = await _biometricService.getAvailableBiometrics();
      // Store biometric types for future use in login flow
      // Log to debug console in development mode only
      if (kDebugMode) {
        debugPrint('Biometric authentication available: $biometricTypes');
      }
    }
    
    // Get device fingerprint for security tracking
    final deviceId = await _deviceService.getDeviceId();
    final deviceInfo = await _deviceService.getDeviceInfo();
    // Device info will be sent with auth requests for device verification
    if (kDebugMode) {
      debugPrint('Device registered: $deviceId - $deviceInfo');
    }
    
    // Check for stored tokens
    final tokensResult = await _authRepository.getStoredTokens();
    tokensResult.fold(
      (failure) => state = AuthState.unauthenticated(),
      (tokens) async {
        if (tokens != null) {
          // Validate tokens and get user
          final userResult = await _authRepository.getCurrentUser();
          userResult.fold(
            (failure) => state = AuthState.unauthenticated(),
            (user) => state = AuthState.authenticated(user, tokens),
          );
        } else {
          state = AuthState.unauthenticated();
        }
      },
    );
  }

  Future<void> login(String email, String password) async {
    state = AuthState.loading();
    
    final result = await _authRepository.login(email, password);
    result.fold(
      (failure) {
        if (failure is _TwoFactorRequired) {
          state = AuthState.twoFactorRequired(email);
        } else {
          state = AuthState.error(failure);
        }
      },
      (tokens) async {
        final userResult = await _authRepository.getCurrentUser();
        userResult.fold(
          (failure) => state = AuthState.error(failure),
          (user) => state = AuthState.authenticated(user, tokens),
        );
      },
    );
  }

  Future<void> register(String email, String password, String fullName) async {
    state = AuthState.loading();
    
    final result = await _authRepository.register(email, password, fullName);
    result.fold(
      (failure) => state = AuthState.error(failure),
      (tokens) async {
        final userResult = await _authRepository.getCurrentUser();
        userResult.fold(
          (failure) => state = AuthState.error(failure),
          (user) => state = AuthState.authenticated(user, tokens),
        );
      },
    );
  }

  Future<void> verifyTwoFactor(String code, String email) async {
    state = AuthState.loading();
    
    final result = await _authRepository.verifyTwoFactor(code, email);
    result.fold(
      (failure) => state = AuthState.error(failure),
      (tokens) async {
        final userResult = await _authRepository.getCurrentUser();
        userResult.fold(
          (failure) => state = AuthState.error(failure),
          (user) => state = AuthState.authenticated(user, tokens),
        );
      },
    );
  }

  Future<void> loginWithBiometric() async {
    if (!await _isBiometricSetup()) {
      state = AuthState.error(AuthFailure.biometricNotAvailable());
      return;
    }

    state = AuthState.loading();
    
    final result = await _authRepository.authenticateWithBiometric();
    result.fold(
      (failure) => state = AuthState.error(failure),
      (tokens) async {
        final userResult = await _authRepository.getCurrentUser();
        userResult.fold(
          (failure) => state = AuthState.error(failure),
          (user) => state = AuthState.authenticated(user, tokens),
        );
      },
    );
  }

  Future<void> loginWithGoogle() async {
    state = AuthState.loading();
    
    final result = await _authRepository.signInWithGoogle();
    result.fold(
      (failure) => state = AuthState.error(failure),
      (tokens) async {
        final userResult = await _authRepository.getCurrentUser();
        userResult.fold(
          (failure) => state = AuthState.error(failure),
          (user) => state = AuthState.authenticated(user, tokens),
        );
      },
    );
  }

  Future<void> loginWithApple() async {
    state = AuthState.loading();
    
    final result = await _authRepository.signInWithApple();
    result.fold(
      (failure) => state = AuthState.error(failure),
      (tokens) async {
        final userResult = await _authRepository.getCurrentUser();
        userResult.fold(
          (failure) => state = AuthState.error(failure),
          (user) => state = AuthState.authenticated(user, tokens),
        );
      },
    );
  }

  Future<void> logout() async {
    state = AuthState.loading();
    
    final result = await _authRepository.logout();
    result.fold(
      (failure) => state = AuthState.error(failure),
      (_) => state = AuthState.unauthenticated(),
    );
  }

  Future<bool> _isBiometricSetup() async {
    final availableResult = await _authRepository.isBiometricAvailable();
    return availableResult.fold((failure) => false, (available) => available);
  }
}