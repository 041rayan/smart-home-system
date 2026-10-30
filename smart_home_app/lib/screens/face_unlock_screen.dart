import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../services/face_unlock_service.dart';

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
  String _statusMessage = 'Position your face in front of the screen';
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
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-trigger biometric scan after screen transition
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
      _statusMessage = 'Authenticating face with device biometrics...';
    });

    if (provider.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 1400));
      _onFaceRecognized();
      return;
    }

    final isAvailable = await _faceService.isBiometricsAvailable();
    if (!isAvailable) {
      setState(() {
        _status = FaceUnlockStatus.failed;
        _statusMessage =
            'Biometrics not enrolled or unavailable. You can use Demo Mode in Settings or simulate unlock below.';
      });
      return;
    }

    final success = await _faceService.authenticateWithFace(
      reason: 'Scan your face to unlock the ESP32 Door',
    );

    if (success && mounted) {
      _onFaceRecognized();
    } else if (mounted) {
      setState(() {
        _status = FaceUnlockStatus.failed;
        _statusMessage = 'Face authentication failed or was canceled.';
      });
    }
  }

  void _onFaceRecognized() {
    final provider = context.read<HomeProvider>();

    setState(() {
      _status = FaceUnlockStatus.success;
      _statusMessage = '✓ Face Verified! Door Unlocked (GPIO 13 @ 90°)';
      _countdown = 4;
    });

    // Send unlock to ESP32 servo
    provider.unlockDoorWithFace();

    // Start auto-lock countdown
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
            _statusMessage = 'Door locked. Tap below to scan again.';
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
        accentColor = const Color(0xFF3D9BFF);
        centerIcon = Icons.face;
        break;
      case FaceUnlockStatus.scanning:
        accentColor = const Color(0xFFFFC43D);
        centerIcon = Icons.face_retouching_natural;
        break;
      case FaceUnlockStatus.success:
        accentColor = const Color(0xFF3DDC84);
        centerIcon = Icons.check_circle_outline;
        break;
      case FaceUnlockStatus.failed:
        accentColor = const Color(0xFFFF453A);
        centerIcon = Icons.face_unlock_rounded;
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1115),
        elevation: 0,
        title: const Text('Face Unlock'),
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
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1A1D24),
                            border: Border.all(
                              color: accentColor,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.25),
                                blurRadius: 28,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Scanner reticle crosshairs
                              Container(
                                width: 170,
                                height: 170,
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
                                size: 90,
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
                          color: Color(0xFF8B909A),
                          height: 1.4,
                        ),
                      ),
                      if (_status == FaceUnlockStatus.success) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14301F),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF3DDC84).withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            'Auto-locking in ${_countdown}s...',
                            style: const TextStyle(
                              color: Color(0xFF3DDC84),
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

              // Action Buttons
              if (_status != FaceUnlockStatus.scanning) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _startFaceScan,
                    icon: const Icon(Icons.face_unlock_rounded),
                    label: Text(
                      _status == FaceUnlockStatus.failed ? 'Retry Face Scan' : 'Scan Face to Unlock',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D9BFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Simulate button for testing
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _onFaceRecognized,
                    icon: const Icon(Icons.touch_app, size: 16),
                    label: const Text('Simulate Authorized Face (Demo)'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8B909A),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
