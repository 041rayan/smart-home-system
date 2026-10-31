import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../screens/face_unlock_screen.dart';
import '../theme/app_theme.dart';

class ControlButtons extends StatelessWidget {
  const ControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final state = provider.state;
    final isDoorOpen = state.doorOpen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            'DEVICES & ACCESS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Front Door Smart Access Card
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDoorOpen ? AppColors.primaryPink : AppColors.cardBorder,
              width: isDoorOpen ? 1.5 : 1.0,
            ),
            boxShadow: isDoorOpen
                ? const [
                    BoxShadow(
                      color: AppColors.pinkGlow,
                      blurRadius: 16,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDoorOpen
                          ? AppColors.primaryPink.withValues(alpha: 0.15)
                          : AppColors.cardElevated,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isDoorOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                      color: isDoorOpen ? AppColors.primaryPink : AppColors.textSecondary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Front Door Lock',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textWhite,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isDoorOpen ? 'Unlocked' : 'Securely Locked',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDoorOpen ? AppColors.primaryPink : AppColors.textSecondary,
                            fontWeight: isDoorOpen ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Lock / Biometric Unlock Action
                  InkWell(
                    onTap: () {
                      if (isDoorOpen) {
                        provider.lockDoor();
                      } else {
                        // Enforce biometric authentication to unlock
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BiometricUnlockScreen(),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isDoorOpen ? null : AppColors.primaryPinkGradient,
                        color: isDoorOpen ? AppColors.cardElevated : null,
                        borderRadius: BorderRadius.circular(12),
                        border: isDoorOpen
                            ? Border.all(color: AppColors.primaryPink.withValues(alpha: 0.5))
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDoorOpen ? Icons.lock_outline_rounded : Icons.fingerprint_rounded,
                            size: 16,
                            color: isDoorOpen ? AppColors.primaryPink : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isDoorOpen ? 'LOCK' : 'BIOMETRIC',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isDoorOpen ? AppColors.primaryPink : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Biometric Unlock action button (Fingerprint & Face)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isDoorOpen) {
                      provider.lockDoor();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BiometricUnlockScreen(),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    isDoorOpen ? Icons.lock_rounded : Icons.fingerprint_rounded,
                    size: 20,
                  ),
                  label: Text(
                    isDoorOpen ? 'Lock Door Now' : 'Biometric Door Access (Fingerprint / Face)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cardElevated,
                    foregroundColor: isDoorOpen ? AppColors.primaryPink : AppColors.softPink,
                    side: BorderSide(
                      color: AppColors.primaryPink.withValues(alpha: 0.35),
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2-Column Device Controls (Bulb & Fan)
        Row(
          children: [
            // Light Bulb Card
            Expanded(
              child: GestureDetector(
                onTap: () => provider.toggleBulb(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: state.bulbOn
                          ? AppColors.primaryPink
                          : AppColors.cardBorder,
                      width: state.bulbOn ? 1.5 : 1.0,
                    ),
                    boxShadow: state.bulbOn
                        ? const [
                            BoxShadow(
                              color: AppColors.pinkGlow,
                              blurRadius: 16,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: state.bulbOn
                                  ? AppColors.primaryPink.withValues(alpha: 0.15)
                                  : AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.lightbulb_rounded,
                              color: state.bulbOn
                                  ? AppColors.primaryPink
                                  : AppColors.textMuted,
                              size: 24,
                            ),
                          ),
                          Switch(
                            value: state.bulbOn,
                            onChanged: (_) => provider.toggleBulb(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Main Light',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.bulbOn ? 'Active' : 'Off',
                        style: TextStyle(
                          fontSize: 12,
                          color: state.bulbOn
                              ? AppColors.primaryPink
                              : AppColors.textSecondary,
                          fontWeight: state.bulbOn ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Fan Card
            Expanded(
              child: GestureDetector(
                onTap: () => provider.toggleFan(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: state.fanOn
                          ? AppColors.primaryPink
                          : AppColors.cardBorder,
                      width: state.fanOn ? 1.5 : 1.0,
                    ),
                    boxShadow: state.fanOn
                        ? const [
                            BoxShadow(
                              color: AppColors.pinkGlow,
                              blurRadius: 16,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: state.fanOn
                                  ? AppColors.primaryPink.withValues(alpha: 0.15)
                                  : AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.air_rounded,
                              color: state.fanOn
                                  ? AppColors.primaryPink
                                  : AppColors.textMuted,
                              size: 24,
                            ),
                          ),
                          Switch(
                            value: state.fanOn,
                            onChanged: (_) => provider.toggleFan(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Ventilation',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.fanOn ? 'Active' : 'Off',
                        style: TextStyle(
                          fontSize: 12,
                          color: state.fanOn
                              ? AppColors.primaryPink
                              : AppColors.textSecondary,
                          fontWeight: state.fanOn ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
