import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../services/face_unlock_service.dart';
import '../theme/app_theme.dart';

enum FaceUnlockStatus { idle, scanning, success, failed }

class FaceUnlockScreen extends StatefulWidget {
  const FaceUnlockScreen({super.key});

  @override
  State<FaceUnlockScreen> createState() => _FaceUnlockScreenState();
}

class _FaceUnlockScreenState extends State<FaceUnlockScreen>
    with SingleTickerProviderStateMixin {
  final FaceUnlockService _faceService = FaceUnlockService();
  FaceUnlockStatus _status = FaceUnlockStatus.idle;
  String _statusMessage = 'Position your face in front of the camera';
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

    // Auto-trigger biometric scan after screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startFaceScan();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startFaceScan() async {
    final provider = context.read<HomeProvider>();

    setState(() {
      _status = FaceUnlockStatus.scanning;
      _statusMessage = 'Verifying facial credentials...';
    });

    if (provider.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 1200));
      _onFaceRecognized();
      return;
    }

    final isAvailable = await _faceService.isBiometricsAvailable();
    if (!isAvailable) {
      setState(() {
        _status = FaceUnlockStatus.failed;
        _statusMessage = 'Biometric security not configured on this device.';
      });
      return;
    }

    final success = await _faceService.authenticateWithFace(
      reason: 'Scan your face to unlock the door',
    );

    if (success && mounted) {
      _onFaceRecognized();
    } else if (mounted) {
      setState(() {
        _status = FaceUnlockStatus.failed;
        _statusMessage = 'Authentication unverified. Please try again.';
      });
    }
  }

  void _onFaceRecognized() {
    final provider = context.read<HomeProvider>();

    setState(() {
      _status = FaceUnlockStatus.success;
      _statusMessage = 'Identity Confirmed • Door Access Granted';
      _countdown = 4;
    });

    provider.unlockDoorWithFace();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {
            _status = FaceUnlockStatus.idle;
            _statusMessage = 'Door locked. Tap below to authenticate.';
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Color accentColor;
    IconData centerIcon;

    switch (_status) {
      case FaceUnlockStatus.idle:
        accentColor = AppColors.softPink;
        centerIcon = Icons.face_rounded;
        break;
      case FaceUnlockStatus.scanning:
        accentColor = AppColors.primaryPink;
        centerIcon = Icons.face_retouching_natural_rounded;
        break;
      case FaceUnlockStatus.success:
        accentColor = AppColors.online;
        centerIcon = Icons.check_circle_outline_rounded;
        break;
      case FaceUnlockStatus.failed:
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
                                size: 84,
                                color: accentColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        _status == FaceUnlockStatus.success
                            ? 'ACCESS GRANTED'
                            : _status == FaceUnlockStatus.scanning
                                ? 'SCANNING FACE'
                                : _status == FaceUnlockStatus.failed
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
                      if (_status == FaceUnlockStatus.success) ...[
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
              if (_status != FaceUnlockStatus.scanning) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _startFaceScan,
                    icon: const Icon(Icons.face_unlock_rounded),
                    label: Text(
                      _status == FaceUnlockStatus.failed
                          ? 'Retry Face Verification'
                          : 'Authenticate Face',
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
