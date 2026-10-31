import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../models/signed_unlock_token.dart';

/// Status of the biometric hardware and enrollment
enum BiometricHardwareStatus {
  ready,
  noHardware,
  hardwareUnavailable,
  noneEnrolled,
  securityUpdateRequired,
  unknown,
}

/// Result of a biometric authentication and signing operation
class BiometricAuthResult {
  final bool success;
  final SignedUnlockToken? token;
  final String? errorCode;
  final String? errorMessage;

  const BiometricAuthResult._({
    required this.success,
    this.token,
    this.errorCode,
    this.errorMessage,
  });

  factory BiometricAuthResult.success(SignedUnlockToken token) {
    return BiometricAuthResult._(
      success: true,
      token: token,
    );
  }

  factory BiometricAuthResult.failure({
    required String errorCode,
    required String errorMessage,
  }) {
    return BiometricAuthResult._(
      success: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  bool get isCanceled =>
      errorCode == 'ERROR_CANCELED' ||
      errorCode == 'USER_CANCELED' ||
      errorCode == 'AUTH_CANCELED';

  bool get isLockout =>
      errorCode == 'ERROR_LOCKOUT' ||
      errorCode == 'ERROR_LOCKOUT_PERMANENT' ||
      errorCode == 'LOCKED_OUT';
}

/// Hardware details reported by Android Keystore and BiometricManager
class BiometricCapabilityInfo {
  final bool canAuthenticate;
  final BiometricHardwareStatus hardwareStatus;
  final bool isStrongBiometric;
  final bool keyExistsInKeystore;
  final String deviceModel;
  final List<BiometricType> availableTypes;
  final String rawStatus;

  const BiometricCapabilityInfo({
    required this.canAuthenticate,
    required this.hardwareStatus,
    required this.isStrongBiometric,
    required this.keyExistsInKeystore,
    required this.deviceModel,
    required this.availableTypes,
    required this.rawStatus,
  });

  String get userFriendlyStatus {
    switch (hardwareStatus) {
      case BiometricHardwareStatus.ready:
        return 'BIOMETRIC_STRONG (Class 3) Ready';
      case BiometricHardwareStatus.noHardware:
        return 'No biometric hardware detected on this device';
      case BiometricHardwareStatus.hardwareUnavailable:
        return 'Biometric hardware currently busy or unavailable';
      case BiometricHardwareStatus.noneEnrolled:
        return 'No biometric (fingerprint/face) enrolled in Android Settings';
      case BiometricHardwareStatus.securityUpdateRequired:
        return 'Security update required before biometrics can be used';
      case BiometricHardwareStatus.unknown:
        return 'Unknown biometric status ($rawStatus)';
    }
  }
}

/// Service providing native Android Keystore key management,
/// strict BIOMETRIC_STRONG authentication via AndroidX BiometricPrompt,
/// and CryptoObject-backed digital signing for door unlocking.
class NativeBiometricAuthService {
  static const MethodChannel _channel =
      MethodChannel('com.example.smart_home/biometric_crypto');
  final LocalAuthentication _localAuth = LocalAuthentication();

  static final NativeBiometricAuthService _instance =
      NativeBiometricAuthService._internal();

  factory NativeBiometricAuthService() => _instance;

  NativeBiometricAuthService._internal();

  /// Inspects device biometric capabilities using both Flutter local_auth
  /// and native AndroidX BiometricManager (Class 3 BIOMETRIC_STRONG).
  Future<BiometricCapabilityInfo> checkBiometricAvailability() async {
    List<BiometricType> availableTypes = [];
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (isSupported) {
        availableTypes = await _localAuth.getAvailableBiometrics();
      }
    } catch (e) {
      debugPrint('LocalAuth getAvailableBiometrics error: $e');
    }

    try {
      final nativeResult = await _channel
          .invokeMapMethod<String, dynamic>('checkBiometricAvailability');

      if (nativeResult != null) {
        final rawStatus = nativeResult['status'] as String? ?? 'UNKNOWN';
        final canAuth = nativeResult['canAuthenticate'] as bool? ?? false;
        final keyExists = nativeResult['keyExists'] as bool? ?? false;
        final deviceModel = nativeResult['deviceModel'] as String? ?? 'Android Device';

        final hwStatus = switch (rawStatus) {
          'SUCCESS' => BiometricHardwareStatus.ready,
          'NO_HARDWARE' => BiometricHardwareStatus.noHardware,
          'HW_UNAVAILABLE' => BiometricHardwareStatus.hardwareUnavailable,
          'NONE_ENROLLED' => BiometricHardwareStatus.noneEnrolled,
          'SECURITY_UPDATE_REQUIRED' =>
            BiometricHardwareStatus.securityUpdateRequired,
          _ => BiometricHardwareStatus.unknown,
        };

        return BiometricCapabilityInfo(
          canAuthenticate: canAuth,
          hardwareStatus: hwStatus,
          isStrongBiometric: true,
          keyExistsInKeystore: keyExists,
          deviceModel: deviceModel,
          availableTypes: availableTypes,
          rawStatus: rawStatus,
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Native checkBiometricAvailability error: $e');
    }

    return BiometricCapabilityInfo(
      canAuthenticate: false,
      hardwareStatus: BiometricHardwareStatus.unknown,
      isStrongBiometric: false,
      keyExistsInKeystore: false,
      deviceModel: 'Android',
      availableTypes: availableTypes,
      rawStatus: 'PLATFORM_CHANNEL_UNAVAILABLE',
    );
  }

  /// Generates a fresh ECDSA secp256r1 keypair inside the Android Keystore (Knox / TEE).
  /// The private key requires BIOMETRIC_STRONG authentication per operation and is NEVER
  /// exported or exposed to application memory.
  Future<Map<String, dynamic>> generateOrRotateKey() async {
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('generateOrRotateKey');
      return result ?? {'success': false, 'error': 'No response from native channel'};
    } on PlatformException catch (e) {
      return {'success': false, 'error': e.message ?? e.toString()};
    }
  }

  /// Retrieves the public key (SubjectPublicKeyInfo DER encoded in Base64) from Android Keystore.
  Future<String?> getPublicKey() async {
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('getPublicKey');
      return result?['publicKey'] as String?;
    } catch (e) {
      debugPrint('Error getting public key: $e');
      return null;
    }
  }

  /// Checks if the Keystore key exists.
  Future<bool> isKeyCreated() async {
    try {
      final result = await _channel.invokeMethod<bool>('isKeyCreated');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Generates a cryptographically random 128-bit hex nonce.
  String _generateSecureNonce() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Authenticates the user with AndroidX BiometricPrompt (Class 3 BIOMETRIC_STRONG only),
  /// unlocks the Keystore private key in hardware, and signs a fresh, replay-resistant unlock token.
  ///
  /// PIN, pattern, and password fallback are STRICTLY disallowed.
  /// If the user cancels or biometric fails, no signature is generated and no unlock command can proceed.
  Future<BiometricAuthResult> authenticateAndSignUnlock({
    String action = 'UNLOCK_DOOR',
    String? customDeviceId,
    String title = 'Authorize Door Unlock',
    String subtitle = 'Class 3 Strong Biometric Authentication',
    String description = 'Touch fingerprint sensor or look at screen to unlock',
  }) async {
    final nonce = _generateSecureNonce();
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final deviceId = customDeviceId ?? 'android_keystore_knox';

    // Canonical JSON payload for deterministic signature verification
    final Map<String, dynamic> payloadMap = {
      'action': action,
      'deviceId': deviceId,
      'nonce': nonce,
      'timestamp': timestamp,
    };
    final canonicalPayload = jsonEncode(payloadMap);

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'authenticateAndSign',
        {
          'payload': canonicalPayload,
          'title': title,
          'subtitle': subtitle,
          'description': description,
        },
      );

      if (result == null) {
        return BiometricAuthResult.failure(
          errorCode: 'NULL_RESULT',
          errorMessage: 'No response received from BiometricPrompt',
        );
      }

      final success = result['success'] as bool? ?? false;
      if (success) {
        final signatureBase64 = result['signatureBase64'] as String? ?? '';
        final publicKeyBase64 = result['publicKeyBase64'] as String? ?? '';
        final algorithm = result['algorithm'] as String? ?? 'SHA256withECDSA';

        final token = SignedUnlockToken(
          action: action,
          nonce: nonce,
          timestamp: timestamp,
          deviceId: deviceId,
          signatureBase64: signatureBase64,
          publicKeyBase64: publicKeyBase64,
          algorithm: algorithm,
          rawPayload: canonicalPayload,
        );

        return BiometricAuthResult.success(token);
      } else {
        final errorCode = result['errorCode'] as String? ?? 'AUTH_FAILED';
        final errorMessage =
            result['errorMessage'] as String? ?? 'Biometric authentication was not completed';
        return BiometricAuthResult.failure(
          errorCode: errorCode,
          errorMessage: errorMessage,
        );
      }
    } on PlatformException catch (e) {
      return BiometricAuthResult.failure(
        errorCode: e.code,
        errorMessage: e.message ?? 'Platform exception during biometric authentication',
      );
    } catch (e) {
      return BiometricAuthResult.failure(
        errorCode: 'UNEXPECTED_ERROR',
        errorMessage: e.toString(),
      );
    }
  }
}
