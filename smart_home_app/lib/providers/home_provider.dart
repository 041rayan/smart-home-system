import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_state.dart';
import '../services/esp32_api_service.dart';
import '../services/notification_service.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class HomeProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  late Esp32ApiService _apiService;

  HomeState _state = HomeState.initial();
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String _esp32Ip = '192.168.0.233';
  bool _isDemoMode = false;
  bool _isBackgroundMonitoringEnabled = true;
  String? _errorMessage;

  Timer? _pollingTimer;
  bool _isPolling = false;
  bool _previousFireState = false;

  HomeState get state => _state;
  ConnectionStatus get connectionStatus => _connectionStatus;
  String get esp32Ip => _esp32Ip;
  bool get isDemoMode => _isDemoMode;
  bool get isBackgroundMonitoringEnabled => _isBackgroundMonitoringEnabled;
  String? get errorMessage => _errorMessage;

  HomeProvider() {
    _apiService = Esp32ApiService(baseUrl: _esp32Ip);
    _initBackgroundListener();
    _loadPreferences();
  }

  void _initBackgroundListener() {
    FlutterBackgroundService().on('state_update').listen((event) {
      if (event != null && !_isDemoMode) {
        try {
          final newState = HomeState.fromJson(Map<String, dynamic>.from(event));
          _handleStateUpdate(newState);
          _connectionStatus = ConnectionStatus.connected;
          _errorMessage = null;
          notifyListeners();
        } catch (e) {
          debugPrint('Error parsing state from background service: $e');
        }
      }
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _esp32Ip = prefs.getString('esp32_ip') ?? '192.168.0.233';
      _isDemoMode = prefs.getBool('demo_mode') ?? false;
      _isBackgroundMonitoringEnabled = prefs.getBool('bg_monitoring_enabled') ?? true;
      _apiService = Esp32ApiService(baseUrl: _esp32Ip);

      if (_isDemoMode) {
        _initDemoState();
      } else {
        startPolling();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      startPolling();
    }
  }

  void startPolling() {
    _pollingTimer?.cancel();
    if (_isDemoMode) return;

    // Immediately poll once
    pollState();

    // Periodic poll every 2 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      pollState();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> pollState() async {
    if (_isPolling || _isDemoMode) return;
    _isPolling = true;

    try {
      if (_connectionStatus == ConnectionStatus.disconnected) {
        _connectionStatus = ConnectionStatus.connecting;
        notifyListeners();
      }

      final newState = await _apiService.fetchState();
      _handleStateUpdate(newState);
      _connectionStatus = ConnectionStatus.connected;
      _errorMessage = null;
    } catch (e) {
      _connectionStatus = ConnectionStatus.disconnected;
      _errorMessage = e.toString();
    } finally {
      _isPolling = false;
      notifyListeners();
    }
  }

  void _handleStateUpdate(HomeState newState) {
    // Check for Fire Alert transition
    if (newState.fireDetected && !_previousFireState) {
      _notificationService.showFireAlert();
    } else if (!newState.fireDetected && _previousFireState) {
      _notificationService.clearFireAlert();
    }
    _previousFireState = newState.fireDetected;
    _state = newState;
  }

  Future<void> setEsp32Ip(String ip) async {
    _esp32Ip = ip.trim();
    _apiService = Esp32ApiService(baseUrl: _esp32Ip);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('esp32_ip', _esp32Ip);

    if (!_isDemoMode) {
      startPolling();
    }
    notifyListeners();
  }

  Future<void> setDemoMode(bool enabled) async {
    _isDemoMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('demo_mode', enabled);

    if (_isDemoMode) {
      stopPolling();
      _initDemoState();
    } else {
      _connectionStatus = ConnectionStatus.disconnected;
      startPolling();
    }
    notifyListeners();
  }

  Future<void> setBackgroundMonitoring(bool enabled) async {
    _isBackgroundMonitoringEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bg_monitoring_enabled', enabled);
    notifyListeners();
  }

  void _initDemoState() {
    _connectionStatus = ConnectionStatus.connected;
    _errorMessage = null;
    _state = HomeState(
      tankPercent: 78,
      tankDistance: 4.2,
      tempC: 28.5,
      humidity: 65,
      fireDetected: false,
      fireRaw: 0,
      flameActiveLow: false,
      doorOpen: false,
      bulbOn: false,
      fanOn: false,
      lastUpdated: DateTime.now(),
    );
  }

  // User Actions
  Future<void> lockDoor() async {
    if (_isDemoMode) {
      _state = _state.copyWith(doorOpen: false, lastUpdated: DateTime.now());
      notifyListeners();
      return;
    }

    try {
      final newState = await _apiService.setDoor(false);
      _handleStateUpdate(newState);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to lock door: $e';
      notifyListeners();
    }
  }

  Future<void> toggleDoor() async {
    if (_state.doorOpen) {
      await lockDoor();
    } else {
      // Security requirement: Door can ONLY be opened with biometric
      _errorMessage = 'Biometric authentication required to unlock door';
      notifyListeners();
    }
  }

  Future<void> testDoorSweep() async {
    if (_isDemoMode) {
      _state = _state.copyWith(doorOpen: true, lastUpdated: DateTime.now());
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 1800));
      _state = _state.copyWith(doorOpen: false, lastUpdated: DateTime.now());
      notifyListeners();
      return;
    }

    try {
      await _apiService.setDoor(true);
      _state = _state.copyWith(doorOpen: true, lastUpdated: DateTime.now());
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 1800));

      final finalState = await _apiService.setDoor(false);
      _handleStateUpdate(finalState);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Sweep test error: $e';
      notifyListeners();
    }
  }

  Future<bool> unlockDoorWithBiometrics() async {
    try {
      if (_isDemoMode) {
        _state = _state.copyWith(doorOpen: true, lastUpdated: DateTime.now());
        notifyListeners();
        await Future.delayed(const Duration(seconds: 4));
        _state = _state.copyWith(doorOpen: false, lastUpdated: DateTime.now());
        notifyListeners();
        return true;
      }

      // Unlock on ESP32
      await _apiService.setDoor(true);
      _state = _state.copyWith(doorOpen: true, lastUpdated: DateTime.now());
      notifyListeners();

      // Keep open for 4 seconds to allow entry
      await Future.delayed(const Duration(seconds: 4));

      // Auto-lock door
      final finalState = await _apiService.setDoor(false);
      _handleStateUpdate(finalState);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Biometric unlock failed: $e';
      notifyListeners();
      return false;
    }
  }

  // Backwards compatibility alias
  Future<bool> unlockDoorWithFace() => unlockDoorWithBiometrics();

  Future<void> toggleBulb() async {
    if (_isDemoMode) {
      _state = _state.copyWith(
        bulbOn: !_state.bulbOn,
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    try {
      final newState = await _apiService.setBulb(!_state.bulbOn);
      _handleStateUpdate(newState);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to toggle bulb: $e';
      notifyListeners();
    }
  }

  Future<void> toggleFan() async {
    if (_isDemoMode) {
      _state = _state.copyWith(
        fanOn: !_state.fanOn,
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    try {
      final newState = await _apiService.setFan(!_state.fanOn);
      _handleStateUpdate(newState);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to toggle fan: $e';
      notifyListeners();
    }
  }

  Future<void> invertFlameLogic() async {
    if (_isDemoMode) {
      final newMode = !_state.flameActiveLow;
      _state = _state.copyWith(
        flameActiveLow: newMode,
        fireDetected: newMode ? (_state.fireRaw == 0) : (_state.fireRaw == 1),
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    try {
      final newState = await _apiService.invertFlame();
      _handleStateUpdate(newState);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to invert flame logic: $e';
      notifyListeners();
    }
  }

  // Demo Controls for testing features without ESP32 hardware
  void triggerDemoFire(bool detected) {
    if (!_isDemoMode) return;
    _state = _state.copyWith(
      fireDetected: detected,
      fireRaw: detected ? 1 : 0,
      lastUpdated: DateTime.now(),
    );

    if (detected) {
      _notificationService.showFireAlert(
        title: '🔥 DEMO FIRE DETECTED!',
        body: 'Simulated fire alert triggered in demo mode! Notification verified.',
        force: true,
      );
    } else {
      _notificationService.clearFireAlert();
    }
    notifyListeners();
  }

  void updateDemoTank(int pct) {
    if (!_isDemoMode) return;
    _state = _state.copyWith(
      tankPercent: pct,
      tankDistance: 12.0 - (pct / 100.0 * 10.0),
      lastUpdated: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> testNotification() async {
    await _notificationService.showTestNotification();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
