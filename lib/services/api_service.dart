import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/alarm_model.dart';

class ApiService {
  final String baseUrl;
  final String password;

  ApiService({required this.baseUrl, this.password = ''});

  // ── Auth ────────────────────────────────────────────────────────────────────

  Future<bool> login(String pwd) async {
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/login'));
      request.bodyFields = {'username': 'admin', 'password': pwd};
      request.followRedirects = false;
      final client = http.Client();
      final streamed =
          await client.send(request).timeout(const Duration(seconds: 6));
      client.close();
      final location = streamed.headers['location'] ?? '';
      // Success when ESP32 redirects to /index.html (not /login.html?err=1)
      return streamed.statusCode == 302 && !location.contains('err=1');
    } catch (_) {
      return false;
    }
  }

  // Silent re-login with saved password, then retry the call once.
  // Handles ESP32 reboots without bothering the user.
  Future<T> _withReauth<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      if (password.isNotEmpty) {
        await login(password);
        return fn();
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await http
          .get(Uri.parse('$baseUrl/logout'))
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  // ── Status ──────────────────────────────────────────────────────────────────

  Future<AlarmStatus> getStatus() => _withReauth(() async {
        final response = await http
            .get(Uri.parse('$baseUrl/api/status'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          return AlarmStatus.fromJson(
              json.decode(response.body) as Map<String, dynamic>);
        }
        throw Exception('Status ${response.statusCode}');
      });

  // ── Alarm control ───────────────────────────────────────────────────────────

  Future<bool> arm() => _postEmpty('/api/arm');
  Future<bool> disarm() => _postEmpty('/api/disarm');
  Future<bool> panic() => _postEmpty('/api/panic');
  Future<bool> stopAlarm() => _postEmpty('/api/stopalarm');

  // ── Volume / Music ──────────────────────────────────────────────────────────

  Future<bool> setVolume(int volume) async {
    try {
      final r = await http
          .post(Uri.parse('$baseUrl/api/volume'), body: volume.toString())
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> playTrack(int track) async {
    try {
      final r = await http
          .post(Uri.parse('$baseUrl/api/play'), body: track.toString())
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopMusic() => _postEmpty('/api/stopmusic');

  // ── Zone pairing — zone index MUST be a URL query param ────────────────────

  Future<bool> pairZone(int zoneIndex) async {
    try {
      final r = await http
          .post(Uri.parse('$baseUrl/api/pair/zone?zone=$zoneIndex'))
          .timeout(const Duration(seconds: 15));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unpairZone(int zoneIndex) async {
    try {
      final r = await http
          .post(Uri.parse('$baseUrl/api/unpair/zone?zone=$zoneIndex'))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Remote pairing ──────────────────────────────────────────────────────────

  Future<bool> pairRemote() async {
    try {
      final r = await http
          .post(Uri.parse('$baseUrl/api/pair/remote'))
          .timeout(const Duration(seconds: 15));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unpairRemote() => _postEmpty('/api/unpair/remote');

  // ── Zone name ───────────────────────────────────────────────────────────────

  Future<bool> setZoneName(int zoneIndex, String name) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/zonename'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'zone=$zoneIndex&name=${Uri.encodeQueryComponent(name)}',
      ).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Song slots ──────────────────────────────────────────────────────────────

  Future<bool> saveSongSlots(List<SongSlot> slots) async {
    try {
      final parts = <String>[];
      for (var i = 0; i < slots.length; i++) {
        final s = slots[i];
        parts
          ..add('s${i}fh=${s.fromH}')
          ..add('s${i}fm=${s.fromM}')
          ..add('s${i}th=${s.toH}')
          ..add('s${i}tm=${s.toM}')
          ..add('s${i}tr=${s.startTrack}')
          ..add('s${i}en=${s.enabled ? 1 : 0}');
      }
      final r = await http.post(
        Uri.parse('$baseUrl/api/songslots'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: parts.join('&'),
      ).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── General settings ────────────────────────────────────────────────────────

  Future<bool> saveSettings({
    required int alarmDur,
    required bool ntpEnabled,
    required bool hourly,
    required bool muteArm,
  }) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/settings'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'alarmDur=$alarmDur'
            '&ntpEnabled=${ntpEnabled ? 1 : 0}'
            '&hourly=${hourly ? 1 : 0}'
            '&muteArm=${muteArm ? 1 : 0}',
      ).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── WiFi ────────────────────────────────────────────────────────────────────

  Future<List<WifiNetwork>> scanWifi() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/api/scan'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final list = json.decode(r.body) as List;
        return list
            .map((n) => WifiNetwork.fromJson(n as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> connectWifi(String ssid, String password) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/wifi'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'ssid=${Uri.encodeQueryComponent(ssid)}'
            '&pass=${Uri.encodeQueryComponent(password)}',
      ).timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Password / PIN ──────────────────────────────────────────────────────────

  Future<bool> changePassword(String newPwd, String pinCode) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/password'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'newpwd=${Uri.encodeQueryComponent(newPwd)}'
            '&pincode=${Uri.encodeQueryComponent(pinCode)}',
      ).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── RTC ─────────────────────────────────────────────────────────────────────

  Future<bool> setTime(DateTime dt) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/settime'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'year=${dt.year}&month=${dt.month}&day=${dt.day}'
            '&hour=${dt.hour}&min=${dt.minute}&sec=${dt.second}',
      ).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Event log ───────────────────────────────────────────────────────────────

  Future<String> getLog() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/api/log'))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200 ? r.body : 'Error ${r.statusCode}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<bool> clearLog() => _postEmpty('/api/clearlog');

  // ── Reboot ──────────────────────────────────────────────────────────────────

  Future<bool> reboot() => _postEmpty('/api/reboot');

  // ── Helper ──────────────────────────────────────────────────────────────────

  Future<bool> _postEmpty(String path) async {
    try {
      final r = await http
          .post(Uri.parse('$baseUrl$path'))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
