import 'package:flutter/foundation.dart';
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
      final biometrics = await getAvailableBiometrics();
      debugPrint('Biometric check - canCheck: $canCheck, isSupported: $isSupported, biometrics: $biometrics');
      return canCheck || isSupported;
    } on PlatformException catch (e) {
      debugPrint('Biometric check error: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('getAvailableBiometrics error: $e');
      return <BiometricType>[];
    }
  }

  Future<bool> authenticateBiometrics({
    String reason = 'Authenticate with fingerprint, face, or PIN to unlock door',
  }) async {
    try {
      final available = await isBiometricsAvailable();
      if (!available) {
        debugPrint('Biometrics not available on device');
        return false;
      }

      final result = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      debugPrint('Biometric auth result: $result');
      return result;
    } on PlatformException catch (e) {
      debugPrint('Biometric PlatformException: code=${e.code}, message=${e.message}, details=${e.details}');
      return false;
    } catch (e) {
      debugPrint('Biometric unexpected error: $e');
      return false;
    }
  }

  // Backwards compatibility alias
  Future<bool> authenticateWithFace({String reason = 'Authenticate to unlock door'}) =>
      authenticateBiometrics(reason: reason);
}

// Backwards-compatible alias
typedef FaceUnlockService = BiometricService;
