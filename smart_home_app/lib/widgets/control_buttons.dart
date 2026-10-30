import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';

class ControlButtons extends StatelessWidget {
  const ControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final state = provider.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONTROLS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Color(0xFF8B909A),
          ),
        ),
        const SizedBox(height: 12),
        // Door Card
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D24),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: state.doorOpen
                  ? const Color(0xFF3DDC84).withValues(alpha: 0.5)
                  : Colors.white10,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: state.doorOpen
                          ? const Color(0xFF14301F)
                          : const Color(0xFF262A33),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      state.doorOpen ? Icons.door_sliding_outlined : Icons.door_front_door,
                      color: state.doorOpen
                          ? const Color(0xFF3DDC84)
                          : const Color(0xFF8B909A),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Door Servo (GPIO 13)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          state.doorOpen ? 'Open (90°)' : 'Closed (0°)',
                          style: TextStyle(
                            fontSize: 13,
                            color: state.doorOpen
                                ? const Color(0xFF3DDC84)
                                : const Color(0xFF8B909A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Toggle Button
                  ElevatedButton(
                    onPressed: () => provider.toggleDoor(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.doorOpen
                          ? const Color(0xFF14301F)
                          : const Color(0xFF262A33),
                      foregroundColor: state.doorOpen
                          ? const Color(0xFF3DDC84)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: state.doorOpen
                              ? const Color(0xFF3DDC84)
                              : Colors.transparent,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    child: Text(state.doorOpen ? 'CLOSE' : 'OPEN'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Sweep Test Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => provider.testDoorSweep(),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Test Door Sweep (0° ➔ 90° ➔ 0°)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B909A),
                    side: const BorderSide(color: Color(0xFF3A3F4B)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Bulb & Fan Row
        Row(
          children: [
            // Bulb Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D24),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: state.bulbOn
                        ? const Color(0xFFFFC43D).withValues(alpha: 0.5)
                        : Colors.white10,
                  ),
                  boxShadow: state.bulbOn
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFC43D).withValues(alpha: 0.15),
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
                        Icon(
                          Icons.lightbulb,
                          color: state.bulbOn
                              ? const Color(0xFFFFC43D)
                              : const Color(0xFF8B909A),
                          size: 28,
                        ),
                        Switch(
                          value: state.bulbOn,
                          onChanged: (_) => provider.toggleBulb(),
                          activeThumbColor: const Color(0xFFFFC43D),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bulb Relay',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      state.bulbOn ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 12,
                        color: state.bulbOn
                            ? const Color(0xFFFFC43D)
                            : const Color(0xFF8B909A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Fan Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D24),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: state.fanOn
                        ? const Color(0xFF3DDC84).withValues(alpha: 0.5)
                        : Colors.white10,
                  ),
                  boxShadow: state.fanOn
                      ? [
                          BoxShadow(
                            color: const Color(0xFF3DDC84).withValues(alpha: 0.15),
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
                        Icon(
                          Icons.mode_fan_off,
                          color: state.fanOn
                              ? const Color(0xFF3DDC84)
                              : const Color(0xFF8B909A),
                          size: 28,
                        ),
                        Switch(
                          value: state.fanOn,
                          onChanged: (_) => provider.toggleFan(),
                          activeThumbColor: const Color(0xFF3DDC84),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fan Relay',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      state.fanOn ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 12,
                        color: state.fanOn
                            ? const Color(0xFF3DDC84)
                            : const Color(0xFF8B909A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
