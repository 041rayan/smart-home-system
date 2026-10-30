import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';

class WaterTankCard extends StatelessWidget {
  const WaterTankCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeProvider>().state;
    final pct = state.tankPercent;
    final dist = state.tankDistance;

    String subtitle = 'Level unknown';
    Color waterColor = const Color(0xFF3D9BFF);

    if (pct != null) {
      if (pct < 15) {
        subtitle = 'Low – refill soon!';
        waterColor = const Color(0xFFFF453A);
      } else if (pct > 90) {
        subtitle = 'Almost full';
        waterColor = const Color(0xFF32D74B);
      } else {
        subtitle = 'Level OK';
        waterColor = const Color(0xFF3D9BFF);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WATER TANK',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Color(0xFF8B909A),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Tank Visual Graphic
              Container(
                width: 70,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFF12151A),
                  border: Border.all(color: const Color(0xFF3A3F4B), width: 3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      height: pct != null ? (pct / 100.0) * 104 : 0,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            waterColor,
                            waterColor.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Values and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pct != null ? '$pct%' : '--%',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: pct != null && pct < 15
                            ? const Color(0xFFFF453A)
                            : const Color(0xFF8B909A),
                      ),
                    ),
                    if (dist != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Distance to surface: ${dist.toStringAsFixed(1)} cm',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF636976),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
