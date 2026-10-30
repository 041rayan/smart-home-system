import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/home_state.dart';

class Esp32ApiService {
  String baseUrl;
  final Duration timeout;

  Esp32ApiService({
    this.baseUrl = 'http://192.168.4.1',
    this.timeout = const Duration(seconds: 5),
  });

  String _cleanUrl(String endpoint) {
    var base = baseUrl.trim();
    // Strip leading schemes if duplicated
    while (base.startsWith('http://http://')) {
      base = base.substring(7);
    }
    while (base.startsWith('https://http://')) {
      base = base.substring(8);
    }
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      base = 'http://$base';
    }
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base$endpoint';
  }

  Future<HomeState> fetchState() async {
    final uri = Uri.parse(_cleanUrl('/api/state'));
    final response = await http.get(uri).timeout(timeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return HomeState.fromJson(json);
    } else {
      throw Exception('Server returned error status: ${response.statusCode}');
    }
  }

  Future<HomeState> setDoor(bool open) async {
    final uri = Uri.parse(_cleanUrl('/api/door?open=${open ? 1 : 0}'));
    final response = await http.get(uri).timeout(timeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return HomeState.fromJson(json);
    } else {
      throw Exception('Failed to set door state: ${response.statusCode}');
    }
  }

  Future<HomeState> setDoorAngle(int angle) async {
    final uri = Uri.parse(_cleanUrl('/api/door?angle=$angle'));
    final response = await http.get(uri).timeout(timeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return HomeState.fromJson(json);
    } else {
      throw Exception('Failed to set servo angle: ${response.statusCode}');
    }
  }

  Future<HomeState> setBulb(bool on) async {
    final uri = Uri.parse(_cleanUrl('/api/bulb?on=${on ? 1 : 0}'));
    final response = await http.get(uri).timeout(timeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return HomeState.fromJson(json);
    } else {
      throw Exception('Failed to set bulb: ${response.statusCode}');
    }
  }

  Future<HomeState> setFan(bool on) async {
    final uri = Uri.parse(_cleanUrl('/api/fan?on=${on ? 1 : 0}'));
    final response = await http.get(uri).timeout(timeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return HomeState.fromJson(json);
    } else {
      throw Exception('Failed to set fan: ${response.statusCode}');
    }
  }

  Future<HomeState> invertFlame() async {
    final uri = Uri.parse(_cleanUrl('/api/flame?invert=1'));
    final response = await http.get(uri).timeout(timeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return HomeState.fromJson(json);
    } else {
      throw Exception('Failed to invert flame logic: ${response.statusCode}');
    }
  }
}
