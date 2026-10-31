import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class BackgroundMonitoringService {
  static const String notificationChannelId = 'smart_home_guard_channel';
  static const int notificationId = 888;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Create notification channel for the foreground service (silent/low importance)
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        notificationChannelId,
        'Smart Home Safety Monitor',
        description: 'Persistent background monitor for real-time fire detection',
        importance: Importance.low,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Smart Home Guard',
        initialNotificationContent: 'Monitoring smart home safety...',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();

    final NotificationService notificationService = NotificationService();
    await notificationService.initialize();

    bool previousFireState = false;

    // Listen for custom commands from foreground app
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Run monitoring loop every 2 seconds
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();

        final bool isDemo = prefs.getBool('demo_mode') ?? false;
        final bool bgEnabled = prefs.getBool('bg_monitoring_enabled') ?? true;
        final String ip = prefs.getString('esp32_ip') ?? '192.168.0.233';

        if (!bgEnabled || isDemo) {
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'Smart Home Guard',
              content: isDemo ? 'Demo mode active' : 'Background monitoring paused',
            );
          }
          return;
        }

        final url = Uri.parse('http://$ip/api/state');
        final response = await http.get(url).timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final bool isFire = data['fire'] == true;

          // Notify UI if app is open
          service.invoke('state_update', data);

          // Handle fire transition
          if (isFire && !previousFireState) {
            await notificationService.showFireAlert(force: true);
          } else if (!isFire && previousFireState) {
            await notificationService.clearFireAlert();
          }
          previousFireState = isFire;

          if (service is AndroidServiceInstance) {
            if (isFire) {
              service.setForegroundNotificationInfo(
                title: '🔥 FIRE HAZARD DETECTED!',
                content: 'Emergency! Flame sensor active at $ip',
              );
            } else {
              final temp = data['temp'];
              final tempStr = temp != null ? '$temp°C' : '--';
              service.setForegroundNotificationInfo(
                title: 'Smart Home Guard • Secure',
                content: 'All systems normal ($tempStr) • Connected to $ip',
              );
            }
          }
        } else {
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'Smart Home Guard',
              content: 'Connecting to controller ($ip)...',
            );
          }
        }
      } catch (e) {
        // Network timeout / offline
        if (service is AndroidServiceInstance) {
          final prefs = await SharedPreferences.getInstance();
          final String ip = prefs.getString('esp32_ip') ?? '192.168.0.233';
          service.setForegroundNotificationInfo(
            title: 'Smart Home Guard',
            content: 'Connecting to $ip...',
          );
        }
      }
    });
  }
}
