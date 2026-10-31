import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }

  Future<bool> authenticateBiometrics({
    String reason = 'Authenticate with fingerprint or face to unlock door',
  }) async {
    try {
      final available = await isBiometricsAvailable();
      if (!available) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      if (e.code == 'NotAvailable' || e.code == 'PasscodeNotSet') {
        return false;
      }
      return false;
    }
  }

  // Backwards compatibility alias
  Future<bool> authenticateWithFace({String reason = 'Authenticate to unlock door'}) =>
      authenticateBiometrics(reason: reason);
}

// Backwards-compatible alias
typedef FaceUnlockService = BiometricService;
