import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipController;
  bool _advancedExpanded = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<HomeProvider>();
    _ipController = TextEditingController(text: provider.esp32Ip);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('System Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        children: [
          // Connection Section
          _buildSectionHeader('ESP32 CONTROLLER CONNECTION'),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.cardBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Controller IP Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ipController,
                  style: const TextStyle(color: AppColors.textWhite),
                  decoration: InputDecoration(
                    hintText: '192.168.0.233 or 192.168.4.1',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.cardElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Home Wi-Fi (192.168.0.233)'),
                      backgroundColor: AppColors.cardElevated,
                      side: const BorderSide(color: AppColors.cardBorder),
                      labelStyle: const TextStyle(
                        color: AppColors.online,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      onPressed: () {
                        _ipController.text = '192.168.0.233';
                      },
                    ),
                    ActionChip(
                      label: const Text('Direct Hotspot (192.168.4.1)'),
                      backgroundColor: AppColors.cardElevated,
                      side: const BorderSide(color: AppColors.cardBorder),
                      labelStyle: const TextStyle(
                        color: AppColors.softPink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      onPressed: () {
                        _ipController.text = '192.168.4.1';
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          provider.setEsp32Ip(_ipController.text);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Connecting to ${_ipController.text}...'),
                              backgroundColor: AppColors.cardElevated,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Save & Connect'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 15, color: AppColors.softPink),
                          SizedBox(width: 6),
                          Text(
                            'Quick Network Tips',
                            style: TextStyle(
                              color: AppColors.softPink,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        '• Home Wi-Fi: Connect phone to "SSH_E_517" and use 192.168.0.233.\n• Direct Hotspot: Connect phone to "ESP32-Home" (pw: 12345678). Turn off Mobile Data so Android doesn\'t bypass local Wi-Fi.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Push Notifications Section
          _buildSectionHeader('PUSH NOTIFICATIONS'),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.cardBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active, color: AppColors.primaryPink, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Fire Alert Push Notifications',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Immediate high-priority alert with custom vibration and alarm sound whenever the flame sensor detects fire.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    await provider.testNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test notification dispatched. Check status bar!'),
                          backgroundColor: AppColors.primaryPink,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send Test Alert Notification'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.softPink,
                    side: const BorderSide(color: AppColors.cardBorder),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Advanced Developer / Maintenance Section
          _buildSectionHeader('DIAGNOSTICS & HARDWARE'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.cardBorder, width: 1),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _advancedExpanded,
                onExpansionChanged: (val) => setState(() => _advancedExpanded = val),
                title: const Text(
                  'Hardware Diagnostics & Tools',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
                subtitle: const Text(
                  'Pin map, sweep test, and simulation',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                children: [
                  const Divider(color: AppColors.cardBorder, height: 1),
                  const SizedBox(height: 14),

                  // Door sweep
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Test Door Servo',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textWhite)),
                          Text('Runs full sweep 0° ➔ 90° ➔ 0°',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                      OutlinedButton(
                        onPressed: () => provider.testDoorSweep(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.softPink,
                          side: const BorderSide(color: AppColors.cardBorder),
                        ),
                        child: const Text('Run Sweep'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Flame Sensor Invert
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Flame Logic Active Level',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textWhite)),
                          Text(
                            provider.state.flameActiveLow ? 'Active LOW' : 'Active HIGH',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      OutlinedButton(
                        onPressed: () => provider.invertFlameLogic(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.softPink,
                          side: const BorderSide(color: AppColors.cardBorder),
                        ),
                        child: const Text('Toggle Logic'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Demo Mode
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Offline Simulation Mode',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textWhite)),
                          Text('Test without live ESP32',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                      Switch(
                        value: provider.isDemoMode,
                        onChanged: (val) => provider.setDemoMode(val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Pin Mapping
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Column(
                      children: [
                        _PinRow(feature: 'Water Ultrasonic TRIG', pin: 'GPIO 5'),
                        _PinRow(feature: 'Water Ultrasonic ECHO', pin: 'GPIO 18'),
                        _PinRow(feature: 'Flame Sensor DO', pin: 'GPIO 27'),
                        _PinRow(feature: 'DHT11 Temp / Humidity', pin: 'GPIO 4'),
                        _PinRow(feature: 'Door Servo Motor', pin: 'GPIO 13'),
                        _PinRow(feature: 'Bulb Relay Module', pin: 'GPIO 22'),
                        _PinRow(feature: 'Fan Relay Module', pin: 'GPIO 23'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  final String feature;
  final String pin;

  const _PinRow({required this.feature, required this.pin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(feature, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(
              pin,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryPink,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
