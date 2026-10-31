import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/signed_unlock_token.dart';
import '../providers/home_provider.dart';
import '../services/native_biometric_auth_service.dart';
import '../theme/app_theme.dart';

enum BiometricUiState {
  initial,
  checkingHardware,
  ready,
  authenticating,
  success,
  failed,
  canceled,
  lockout,
  hardwareUnavailable,
}

class BiometricUnlockScreen extends StatefulWidget {
  const BiometricUnlockScreen({super.key});

  @override
  State<BiometricUnlockScreen> createState() => _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends State<BiometricUnlockScreen>
    with SingleTickerProviderStateMixin {
  final NativeBiometricAuthService _authService = NativeBiometricAuthService();

  BiometricUiState _uiState = BiometricUiState.checkingHardware;
  BiometricCapabilityInfo? _capabilityInfo;
  SignedUnlockToken? _authenticatedToken;
  String? _errorMessage;
  String? _statusHeadline = 'Verifying Biometric Hardware...';
  String? _statusSubtext = 'Checking Android Keystore & Knox TEE integrity';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkCapabilitiesAndPrepare();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkCapabilitiesAndPrepare() async {
    setState(() {
      _uiState = BiometricUiState.checkingHardware;
      _statusHeadline = 'Querying Hardware Security...';
      _statusSubtext = 'Checking BIOMETRIC_STRONG (Class 3) and Keystore status';
    });

    final info = await _authService.checkBiometricAvailability();

    if (!mounted) return;

    setState(() {
      _capabilityInfo = info;
    });

    if (!info.canAuthenticate) {
      setState(() {
        _uiState = BiometricUiState.hardwareUnavailable;
        _errorMessage = info.userFriendlyStatus;
        _statusHeadline = 'Biometric Ineligible';
        _statusSubtext = info.userFriendlyStatus;
      });
      return;
    }

    // Ensure hardware Keystore key exists
    if (!info.keyExistsInKeystore) {
      setState(() {
        _statusHeadline = 'Initializing Knox Keystore Key...';
        _statusSubtext = 'Generating authentication-bound secp256r1 keypair';
      });
      await _authService.generateOrRotateKey();
    }

    setState(() {
      _uiState = BiometricUiState.ready;
      _statusHeadline = 'Biometric Authorization Ready';
      _statusSubtext =
          'Protected by Samsung Knox TEE & Android Keystore.\nTap button below or sensor to unlock.';
      _errorMessage = null;
    });
  }

  Future<void> _startBiometricAuthentication() async {
    if (_uiState == BiometricUiState.authenticating) return;

    final provider = context.read<HomeProvider>();

    setState(() {
      _uiState = BiometricUiState.authenticating;
      _statusHeadline = 'Awaiting Biometric Confirmation...';
      _statusSubtext =
          'Touch your enrolled fingerprint or present your face.\nNo PIN or password fallback allowed.';
      _errorMessage = null;
    });

    final result = await _authService.authenticateAndSignUnlock(
      action: 'UNLOCK_DOOR',
      customDeviceId: 'samsung_knox_s24u',
      title: 'Smart Home Door Unlock',
      subtitle: 'Class 3 BIOMETRIC_STRONG Security',
      description: 'Confirm your biometric identity to unlock the front door',
    );

    if (!mounted) return;

    if (result.success && result.token != null) {
      final token = result.token!;
      setState(() {
        _uiState = BiometricUiState.success;
        _authenticatedToken = token;
        _statusHeadline = 'Biometric Verified & Signed!';
        _statusSubtext =
            'Fresh cryptographic token signed in hardware TEE.\nTransmitting unlock command to ESP32...';
      });

      // Transmit signed authorization token to ESP32 via HomeProvider
      final unlockSuccess = await provider.unlockDoorWithBiometrics(token: token);

      if (!mounted) return;

      if (unlockSuccess) {
        setState(() {
          _statusHeadline = 'Door Successfully Unlocked!';
          _statusSubtext = 'ESP32 servo engaged. Door will auto-lock in 5 seconds.';
        });

        // Close after 2.5 seconds to return to dashboard
        _autoCloseTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
      } else {
        setState(() {
          _uiState = BiometricUiState.failed;
          _errorMessage = provider.errorMessage ?? 'ESP32 unlock command failed to dispatch';
          _statusHeadline = 'Transmission Failed';
          _statusSubtext = 'Biometrics succeeded, but ESP32 controller did not respond.';
        });
      }
    } else {
      // Authentication failed or canceled - NEVER send unlock command!
      if (result.isCanceled) {
        setState(() {
          _uiState = BiometricUiState.canceled;
          _errorMessage = 'Biometric authentication was canceled';
          _statusHeadline = 'Authentication Canceled';
          _statusSubtext = 'Unlock aborted. No credentials or commands were sent.';
        });
      } else if (result.isLockout) {
        setState(() {
          _uiState = BiometricUiState.lockout;
          _errorMessage =
              'Sensor temporarily locked due to too many failed attempts. Try again later.';
          _statusHeadline = 'Biometric Sensor Locked Out';
          _statusSubtext = 'Please wait 30 seconds for Android security lockout to expire.';
        });
      } else {
        setState(() {
          _uiState = BiometricUiState.failed;
          _errorMessage = result.errorMessage ?? 'Biometric verification failed';
          _statusHeadline = 'Biometric Verification Failed';
          _statusSubtext = 'The biometric presented did not match the authorized phone owner.';
        });
      }
    }
  }

  Future<void> _rotateKey() async {
    setState(() {
      _statusHeadline = 'Rotating Keystore Key...';
    });
    final gen = await _authService.generateOrRotateKey();
    if (gen['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New Knox TEE secp256r1 Keypair Generated!'),
            backgroundColor: AppColors.online,
          ),
        );
      }
      _checkCapabilitiesAndPrepare();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Key rotation failed: ${gen['error']}'),
            backgroundColor: AppColors.fireAlert,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Biometric Door Access',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textWhite,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined, color: AppColors.textSecondary, size: 20),
            tooltip: 'Rotate Hardware Key',
            onPressed: _rotateKey,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 22),
            tooltip: 'Refresh Status',
            onPressed: _checkCapabilitiesAndPrepare,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          children: [
            _buildSecurityHeaderBadge(),
            const SizedBox(height: 18),
            _buildInteractiveBiometricHero(),
            const SizedBox(height: 20),
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildEsp32HotspotSelector(provider),
            if (_authenticatedToken != null) ...[
              const SizedBox(height: 16),
              _buildCryptographicProofCard(_authenticatedToken!),
            ],
            const SizedBox(height: 22),
            _buildActionButtons(provider),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityHeaderBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryPink.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: AppColors.primaryPink,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'BIOMETRIC_STRONG (Class 3)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.online.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'TEE BOUND',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.online,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'No PIN/Pattern Fallback • Android Keystore secp256r1',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveBiometricHero() {
    Color heroColor;
    IconData heroIcon;

    switch (_uiState) {
      case BiometricUiState.success:
        heroColor = AppColors.online;
        heroIcon = Icons.check_circle_rounded;
        break;
      case BiometricUiState.authenticating:
        heroColor = AppColors.primaryPink;
        heroIcon = Icons.fingerprint_rounded;
        break;
      case BiometricUiState.lockout:
      case BiometricUiState.hardwareUnavailable:
        heroColor = AppColors.fireAlert;
        heroIcon = Icons.lock_clock_rounded;
        break;
      case BiometricUiState.failed:
      case BiometricUiState.canceled:
        heroColor = AppColors.warning;
        heroIcon = Icons.error_outline_rounded;
        break;
      case BiometricUiState.ready:
      default:
        heroColor = AppColors.primaryPink;
        heroIcon = Icons.fingerprint_rounded;
        break;
    }

    final isScanning = _uiState == BiometricUiState.authenticating;

    return Center(
      child: Column(
        children: [
          ScaleTransition(
            scale: isScanning ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    heroColor.withValues(alpha: 0.25),
                    heroColor.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.3, 0.7, 1.0],
                ),
                border: Border.all(
                  color: heroColor.withValues(alpha: isScanning ? 0.9 : 0.4),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: heroColor.withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  heroIcon,
                  size: 68,
                  color: heroColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _statusHeadline ?? 'Biometric Authentication',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textWhite,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _statusSubtext ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.fireAlert.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.fireAlert.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.fireAlert, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Security Notice',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.fireAlert,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textWhite),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final model = _capabilityInfo?.deviceModel ?? 'Samsung Galaxy';
    final keyExists = _capabilityInfo?.keyExistsInKeystore ?? true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            icon: Icons.smartphone_rounded,
            label: 'Hardware Platform',
            value: model,
            valueColor: AppColors.textWhite,
          ),
          const Divider(color: AppColors.cardBorder, height: 16),
          _buildDetailRow(
            icon: Icons.shield_rounded,
            label: 'Hardware Keystore',
            value: keyExists ? 'Protected in Knox TEE' : 'Not Generated',
            valueColor: keyExists ? AppColors.online : AppColors.warning,
          ),
          const Divider(color: AppColors.cardBorder, height: 16),
          _buildDetailRow(
            icon: Icons.fingerprint,
            label: 'Authenticator Policy',
            value: 'BIOMETRIC_STRONG (Zero PIN Fallback)',
            valueColor: AppColors.softPink,
          ),
        ],
      ),
    );
  }

  Widget _buildEsp32HotspotSelector(HomeProvider provider) {
    final currentIp = provider.esp32Ip;
    final isHotspot = currentIp.contains('10.202.5.');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isHotspot ? Icons.wifi_tethering_rounded : Icons.wifi_rounded,
                    size: 18,
                    color: AppColors.primaryPink,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Target ESP32 Controller',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isHotspot
                      ? AppColors.online.withValues(alpha: 0.15)
                      : AppColors.primaryPink.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isHotspot ? 'HOTSPOT SUBNET' : 'HOME WI-FI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isHotspot ? AppColors.online : AppColors.primaryPink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => provider.switchToHotspot(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isHotspot ? AppColors.cardElevated : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isHotspot ? AppColors.online : AppColors.cardBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phone Hotspot',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isHotspot ? AppColors.online : AppColors.textMuted,
                          ),
                        ),
                        const Text(
                          '10.202.5.35',
                          style: TextStyle(fontSize: 12, color: AppColors.textWhite),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => provider.switchToWifi(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: !isHotspot ? AppColors.cardElevated : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !isHotspot ? AppColors.primaryPink : AppColors.cardBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Home Wi-Fi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: !isHotspot ? AppColors.primaryPink : AppColors.textMuted,
                          ),
                        ),
                        const Text(
                          '192.168.0.233',
                          style: TextStyle(fontSize: 12, color: AppColors.textWhite),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCryptographicProofCard(SignedUnlockToken token) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.online.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2200E676),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: AppColors.online, size: 18),
              SizedBox(width: 8),
              Text(
                'Fresh Signed Authorization Token',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.online,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTokenField('Replay Nonce', token.nonce),
          _buildTokenField('Timestamp (UTC)', '${token.timestamp} (${DateTime.fromMillisecondsSinceEpoch(token.timestamp).toIso8601String()})'),
          _buildTokenField('Algorithm', token.algorithm),
          _buildTokenField('ECDSA Signature', token.shortSignature),
          _buildTokenField('Public Key DER', token.shortPublicKey),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.softPink),
                label: const Text('Copy Token JSON', style: TextStyle(fontSize: 12, color: AppColors.softPink)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: token.serialize()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed token copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppColors.textWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(HomeProvider provider) {
    final isProcessing = _uiState == BiometricUiState.authenticating ||
        _uiState == BiometricUiState.checkingHardware;

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: isProcessing ? null : AppColors.primaryPinkGradient,
            color: isProcessing ? AppColors.cardBorder : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isProcessing
                ? null
                : const [
                    BoxShadow(
                      color: AppColors.pinkGlow,
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
          ),
          child: ElevatedButton(
            onPressed: isProcessing ? null : _startBiometricAuthentication,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.textWhite,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Authenticating with Knox...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint_rounded, size: 24, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Authenticate & Unlock Door',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
