import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';

class FireAlertBanner extends StatefulWidget {
  const FireAlertBanner({super.key});

  @override
  State<FireAlertBanner> createState() => _FireAlertBannerState();
}

class _FireAlertBannerState extends State<FireAlertBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final state = provider.state;
    final isFire = state.fireDetected;

    if (isFire) {
      return ScaleTransition(
        scale: _pulseAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF4A1616),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFF453A), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF453A).withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF453A).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Color(0xFFFF453A),
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔥 FIRE DETECTED!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check immediately! DO Pin: ${state.fireRaw == 1 ? "HIGH" : "LOW"}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFFF9F0A),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => provider.invertFlameLogic(),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black26,
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                child: const Text('Invert', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    // Normal safe condition
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFF3DDC84),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No fire detected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Flame sensor OK • Pin DO: ${state.fireRaw == 1 ? "HIGH" : "LOW"} (${state.flameActiveLow ? "Active-LOW" : "Active-HIGH"})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8B909A),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => provider.invertFlameLogic(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8B909A),
              side: const BorderSide(color: Color(0xFF3A3F4B)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Invert', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
