import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipController;

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
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1115),
        elevation: 0,
        title: const Text('Settings & Testing'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Connection Section
          _buildSectionHeader('ESP32 CONNECTION'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESP32 IP / Hostname',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ipController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '192.168.4.1',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF262A33),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        provider.setEsp32Ip(_ipController.text);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ESP32 IP updated! Connecting...')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D9BFF),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save & Connect'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        _ipController.text = '192.168.4.1';
                        provider.setEsp32Ip('192.168.4.1');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B909A),
                        side: const BorderSide(color: Color(0xFF3A3F4B)),
                      ),
                      child: const Text('Reset Default'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Push Notifications Section
          _buildSectionHeader('PUSH NOTIFICATIONS'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active, color: Color(0xFFFF453A)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Fire Emergency Alerts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'The app uses high-priority local push notifications with vibration and critical sound when the flame sensor trips.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8B909A)),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () async {
                    await provider.testNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test Fire notification sent! Check notification tray.'),
                          backgroundColor: Color(0xFFFF453A),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Send Test Fire Alert Notification'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF453A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Feature Testing / Demo Mode Section
          _buildSectionHeader('FEATURE SIMULATION / DEMO MODE'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demo / Simulation Mode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Test features without ESP32 connected',
                          style: TextStyle(fontSize: 12, color: Color(0xFF8B909A)),
                        ),
                      ],
                    ),
                    Switch(
                      value: provider.isDemoMode,
                      onChanged: (val) => provider.setDemoMode(val),
                      activeThumbColor: const Color(0xFF3D9BFF),
                    ),
                  ],
                ),
                if (provider.isDemoMode) ...[
                  const Divider(color: Colors.white10, height: 24),
                  const Text(
                    'Simulate Hardware Events:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B909A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => provider.triggerDemoFire(true),
                          icon: const Icon(Icons.local_fire_department, size: 18),
                          label: const Text('Trigger Fire'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A1616),
                            foregroundColor: const Color(0xFFFF453A),
                            side: const BorderSide(color: Color(0xFFFF453A)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => provider.triggerDemoFire(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3DDC84),
                            side: const BorderSide(color: Color(0xFF3DDC84)),
                          ),
                          child: const Text('Clear Fire'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Simulate Water Tank Level:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8B909A)),
                  ),
                  Slider(
                    value: (provider.state.tankPercent ?? 50).toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${provider.state.tankPercent}%',
                    activeColor: const Color(0xFF3D9BFF),
                    onChanged: (val) => provider.updateDemoTank(val.toInt()),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Hardware Reference Section
          _buildSectionHeader('HARDWARE PIN MAPPING'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Color(0xFF8B909A),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(feature, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF262A33),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              pin,
              style: const TextStyle(
                color: Color(0xFFFFC43D),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
