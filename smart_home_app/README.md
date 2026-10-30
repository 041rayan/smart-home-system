# ESP32 Smart Home Flutter App

A modern, high-performance Flutter app designed to monitor and control your ESP32-based Smart Home System with **real-time push notifications for fire detection**.

---

## Features

- **🔥 Fire Detection & Push Notifications**:
  - High-priority local push notification triggered immediately when flame sensor trips.
  - Full-screen audible alert channel with emergency vibration pattern.
  - Flame logic inverter button (`Active-HIGH` / `Active-LOW`) directly from the app.
- **💧 Water Tank Monitoring**:
  - Animated tank graphic showing current water depth and percentage (0% – 100%).
  - Real-time ultrasonic distance readout in centimeters.
  - Low water level alert warning (< 15%).
- **🌡️ Room Climate**:
  - DHT11 / DHT22 live temperature (°C) and humidity (%) display.
- **🚪 Door Servo Control**:
  - Open (90°) / Close (0°) toggle.
  - Dedicated **"Test Door Sweep"** button (0° ➔ 90° ➔ 0°) to verify servo movement.
- **💡 Appliance Relays**:
  - Bulb relay switch with golden ambient glow.
  - Fan relay switch with status indicator.
- **🧪 Demo / Feature Simulation Mode**:
  - Complete offline testing mode: simulates the ESP32 hardware without needing to be connected to the ESP32 Wi-Fi.
  - Includes a **"Trigger Fire"** button in Settings to test and verify push notifications on your device anytime.

---

## Project Structure

```
smart_home_app/
├── lib/
│   ├── main.dart                          # App entry point & Notification initialization
│   ├── models/
│   │   └── home_state.dart                # ESP32 state data model
│   ├── services/
│   │   ├── esp32_api_service.dart         # HTTP REST API client
│   │   └── notification_service.dart      # FlutterLocalNotifications high-priority channel
│   ├── providers/
│   │   └── home_provider.dart             # State management & periodic polling
│   ├── screens/
│   │   ├── home_screen.dart               # Main dashboard UI
│   │   └── settings_screen.dart           # IP config, Demo mode, & Notification test
│   └── widgets/
│       ├── fire_alert_banner.dart         # Animated pulsing fire alert card
│       ├── water_tank_card.dart           # Animated water cylinder graphic
│       ├── climate_card.dart              # Temp & Humidity cards
│       └── control_buttons.dart           # Door, Bulb, and Fan controls
└── pubspec.yaml
```

---

## How to Run the App

### 1. Connect to the ESP32 Wi-Fi
On your smartphone:
- **SSID**: `ESP32-Home`
- **Password**: `12345678`
*(Default IP is `192.168.4.1`)*

### 2. Launch the Flutter App
From within the `smart_home_app` directory:

```bash
cd smart_home_app
flutter pub get
flutter run
```

### 3. Testing Push Notifications
1. Open the app.
2. Tap the **Settings** icon (top right).
3. Tap **"Send Test Fire Alert Notification"** to verify that notifications, sound, and vibration display on your phone.
4. Or enable **"Demo Mode"** and tap **"Trigger Fire"** to see the full alert flow in action!
