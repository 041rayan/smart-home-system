import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../services/face_unlock_service.dart';
import '../theme/app_theme.dart';

enum BiometricStatus { idle, scanning, success, failed }

class BiometricUnlockScreen extends StatefulWidget {
  const BiometricUnlockScreen({super.key});

  @override
  State<BiometricUnlockScreen> createState() => _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends State<BiometricUnlockScreen>
    with SingleTickerProviderStateMixin {
  final BiometricService _biometricService = BiometricService();
  BiometricStatus _status = BiometricStatus.idle;
  String _statusMessage = 'Scan your fingerprint or face to unlock';
  int _countdown = 4;
  Timer? _countdownTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-trigger biometric prompt after screen transition
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBiometricScan();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startBiometricScan() async {
    final provider = context.read<HomeProvider>();

    setState(() {
      _status = BiometricStatus.scanning;
      _statusMessage = 'Authenticating biometric credentials...';
    });

    if (provider.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 1200));
      _onBiometricRecognized();
      return;
    }

    final isAvailable = await _biometricService.isBiometricsAvailable();
    if (!isAvailable) {
      setState(() {
        _status = BiometricStatus.failed;
        _statusMessage = 'Biometric security not configured on this device.';
      });
      return;
    }

    final success = await _biometricService.authenticateBiometrics(
      reason: 'Scan your fingerprint or face to unlock the door',
    );

    if (success && mounted) {
      _onBiometricRecognized();
    } else if (mounted) {
      setState(() {
        _status = BiometricStatus.failed;
        _statusMessage = 'Biometric authentication failed. Please try again.';
      });
    }
  }

  void _onBiometricRecognized() {
    final provider = context.read<HomeProvider>();

    setState(() {
      _status = BiometricStatus.success;
      _statusMessage = 'Biometrics Confirmed • Door Access Granted';
      _countdown = 4;
    });

    provider.unlockDoorWithBiometrics();

    // Smoothly return to dashboard after brief confirmation
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Color accentColor;
    IconData centerIcon;

    switch (_status) {
      case BiometricStatus.idle:
        accentColor = AppColors.softPink;
        centerIcon = Icons.fingerprint_rounded;
        break;
      case BiometricStatus.scanning:
        accentColor = AppColors.primaryPink;
        centerIcon = Icons.fingerprint_rounded;
        break;
      case BiometricStatus.success:
        accentColor = AppColors.online;
        centerIcon = Icons.check_circle_outline_rounded;
        break;
      case BiometricStatus.failed:
        accentColor = AppColors.fireAlert;
        centerIcon = Icons.error_outline_rounded;
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Biometric Door Access'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Biometric HUD Scanner View
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cardSurface,
                            border: Border.all(
                              color: accentColor,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.25),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Scanner reticle
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              Icon(
                                centerIcon,
                                size: 88,
                                color: accentColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        _status == BiometricStatus.success
                            ? 'ACCESS GRANTED'
                            : _status == BiometricStatus.scanning
                                ? 'VERIFYING BIOMETRICS'
                                : _status == BiometricStatus.failed
                                    ? 'ACCESS DENIED'
                                    : 'DOOR LOCKED',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (_status == BiometricStatus.success) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.online.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.online.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'Auto-locking in ${_countdown}s…',
                            style: const TextStyle(
                              color: AppColors.online,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Action button
              if (_status != BiometricStatus.scanning) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _startBiometricScan,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: Text(
                      _status == BiometricStatus.failed
                          ? 'Retry Biometric Scan'
                          : 'Authenticate Biometrics',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// Backwards compatibility alias
typedef FaceUnlockScreen = BiometricUnlockScreen;
