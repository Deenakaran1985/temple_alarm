import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/alarm_model.dart';

class ApiService {
  String baseUrl;
  
  ApiService({required this.baseUrl});

  // Get system status
  Future<AlarmStatus> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return AlarmStatus.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Arm the system
  Future<bool> armSystem() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/arm'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Disarm the system
  Future<bool> disarmSystem() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/disarm'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Test siren
  Future<bool> testSiren() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/test'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Set volume
  Future<bool> setVolume(int volume) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/volume'),
        body: volume.toString(),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Pair a zone
  Future<bool> pairZone(int zone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/pair/zone'),
        body: 'zone=$zone',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 12));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Pair remote
  Future<bool> pairRemote() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/pair/remote'),
      ).timeout(const Duration(seconds: 16));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}