// Biometric Service.
// Pattern: Service Pattern - biometric authentication operations.
// Single Responsibility: Biometric authentication management.
// File size: <100 lines as per CLAUDE.md requirements.

import 'package:local_auth/local_auth.dart';

abstract class BiometricService {
  Future<bool> isBiometricAvailable();
  Future<bool> isDeviceEnrolled();
  Future<bool> authenticate({String? reason});
  Future<bool> isAvailable();
  Future<List<BiometricType>> getAvailableBiometrics();
}

class BiometricServiceImpl implements BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isDeviceEnrolled() async {
    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({String? reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason ?? 'Please authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    return isBiometricAvailable();
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }
}