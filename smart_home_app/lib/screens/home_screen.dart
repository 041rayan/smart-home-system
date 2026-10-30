import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../widgets/fire_alert_banner.dart';
import '../widgets/water_tank_card.dart';
import '../widgets/climate_card.dart';
import '../widgets/control_buttons.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1115),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Home Controller',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            _buildConnectionBadge(provider),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF8B909A)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.pollState(),
        color: const Color(0xFF3D9BFF),
        backgroundColor: const Color(0xFF1A1D24),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            if (provider.isDemoMode) _buildDemoModeBanner(context, provider),
            const FireAlertBanner(),
            const WaterTankCard(),
            const ClimateCard(),
            const ControlButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBadge(HomeProvider provider) {
    Color dotColor;
    String text;

    if (provider.isDemoMode) {
      dotColor = const Color(0xFF3D9BFF);
      text = 'Simulation Mode';
    } else {
      switch (provider.connectionStatus) {
        case ConnectionStatus.connected:
          dotColor = const Color(0xFF3DDC84);
          text = 'Connected (${provider.esp32Ip})';
          break;
        case ConnectionStatus.connecting:
          dotColor = const Color(0xFFFFC43D);
          text = 'Connecting…';
          break;
        case ConnectionStatus.disconnected:
          dotColor = const Color(0xFFFF453A);
          text = 'Disconnected – retrying…';
          break;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF8B909A),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoModeBanner(BuildContext context, HomeProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF192638),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3D9BFF).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science, color: Color(0xFF3D9BFF), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Demo Mode active: Hardware simulated',
              style: TextStyle(color: Color(0xFF3D9BFF), fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => provider.setDemoMode(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Exit', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
