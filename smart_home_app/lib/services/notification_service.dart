import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  DateTime? _lastAlertTime;

  static const String fireChannelId = 'fire_alerts_channel';
  static const String fireChannelName = 'Fire Emergency Alerts';
  static const String fireChannelDesc =
      'High-priority emergency alerts triggered by the ESP32 flame sensor';
  static const int fireNotificationId = 101;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click if needed
      },
    );

    // Create high-importance notification channel on Android
    if (Platform.isAndroid) {
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        fireChannelId,
        fireChannelName,
        description: fireChannelDesc,
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      );

      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.createNotificationChannel(channel);
      await requestPermissions();
    }

    _isInitialized = true;
  }

  Future<bool?> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      return await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return true;
  }

  Future<void> showFireAlert({
    String title = '🔥 FIRE DETECTED!',
    String body = 'Emergency: Flame sensor on ESP32 detected fire! Check immediately.',
    bool force = false,
  }) async {
    final now = DateTime.now();
    // Throttle to avoid repeated alerts every 2s, but alert immediately on first trigger
    if (!force && _lastAlertTime != null) {
      final elapsed = now.difference(_lastAlertTime!).inSeconds;
      if (elapsed < 10) return;
    }
    _lastAlertTime = now;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      fireChannelId,
      fireChannelName,
      channelDescription: fireChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'FIRE ALERT',
      color: Color(0xFFFF3B30),
      enableLights: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      styleInformation: BigTextStyleInformation(
        'EMERGENCY ALERT: Flame sensor tripped on smart home controller.\nPlease inspect the area and take safety precautions immediately!',
        contentTitle: '🔥 <b>FIRE DETECTED!</b>',
        htmlFormatContentTitle: true,
        htmlFormatBigText: true,
      ),
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.critical,
      ),
    );

    await _notificationsPlugin.show(
      fireNotificationId,
      title,
      body,
      platformDetails,
    );
  }

  Future<void> showTestNotification() async {
    await showFireAlert(
      title: '🔥 Test Fire Alert',
      body: 'Push notification system is working! You will receive critical alerts when fire is detected.',
      force: true,
    );
  }

  Future<void> clearFireAlert() async {
    await _notificationsPlugin.cancel(fireNotificationId);
  }
}
