import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../theme/app_theme.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Smart',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.textWhite,
                  ),
                ),
                Text(
                  'Home',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    foreground: Paint()
                      ..shader = AppColors.primaryPinkGradient.createShader(
                        const Rect.fromLTWH(0, 0, 70, 24),
                      ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            _buildConnectionBadge(context, provider),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder, width: 1),
              ),
              child: IconButton(
                icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 21),
                splashRadius: 22,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.pollState(),
        color: AppColors.primaryPink,
        backgroundColor: AppColors.cardSurface,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          children: const [
            FireAlertBanner(),
            WaterTankCard(),
            ClimateCard(),
            ControlButtons(),
            SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBadge(BuildContext context, HomeProvider provider) {
    Color dotColor;
    String text;

    if (provider.isDemoMode) {
      dotColor = AppColors.softPink;
      text = 'Offline Simulation';
    } else {
      switch (provider.connectionStatus) {
        case ConnectionStatus.connected:
          dotColor = AppColors.online;
          text = 'Online • ${provider.esp32Ip}';
          break;
        case ConnectionStatus.connecting:
          dotColor = AppColors.warning;
          text = 'Connecting…';
          break;
        case ConnectionStatus.disconnected:
          dotColor = AppColors.fireAlert;
          text = 'Offline • Tap Settings to reconnect';
          break;
      }
    }

    return GestureDetector(
      onTap: () {
        if (provider.connectionStatus == ConnectionStatus.disconnected) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
