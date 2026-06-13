/// Biometric and device-credential authentication for password reveal etc.
library;

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../core/app_logger.dart';

class BiometricService {
  BiometricService() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  /// Check if biometric authentication is available.
  Future<bool> isBiometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } on PlatformException catch (e) {
      AppLogger.error('Error checking biometrics', e);
      return false;
    }
  }

  /// Get list of available biometric types.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      AppLogger.error('Error getting biometrics', e);
      return <BiometricType>[];
    }
  }

  /// Authenticate with biometrics only.
  Future<bool> authenticate({
    required String reason,
    bool stickyAuth = true,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: stickyAuth,
        ),
      );
    } on PlatformException catch (e) {
      AppLogger.error('Authentication error', e);
      return false;
    }
  }

  /// Authenticate with device credentials (PIN/pattern/password) or biometric.
  Future<bool> authenticateWithCredentials({
    required String reason,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      AppLogger.error('Authentication error', e);
      return false;
    }
  }

  /// Stop in-progress authentication.
  Future<void> stopAuthentication() async {
    await _auth.stopAuthentication();
  }
}
