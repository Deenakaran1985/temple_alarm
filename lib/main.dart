import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const TempleAlarmApp());
}

class TempleAlarmApp extends StatelessWidget {
  const TempleAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temple Alarm System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4a6fa5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4a6fa5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ConnectionGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ConnectionGate extends StatefulWidget {
  const ConnectionGate({super.key});

  @override
  State<ConnectionGate> createState() => _ConnectionGateState();
}

class _ConnectionGateState extends State<ConnectionGate> {
  String? savedIp;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      savedIp = prefs.getString('esp32_ip');
      isLoading = false;
    });
  }

  Future<void> _saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('esp32_ip', ip);
    setState(() {
      savedIp = ip;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (savedIp == null) {
      return LoginScreen(onIpSaved: _saveIp);
    }

    // Test connection to ESP32
    return FutureBuilder(
      future: ApiService(baseUrl: 'http://$savedIp').getStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Connecting to ESP32...'),
              ],
            )),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 64, color: Colors.red),
                  const SizedBox(height: 20),
                  const Text('Cannot connect to ESP32'),
                  const SizedBox(height: 10),
                  Text('IP: $savedIp', style: const TextStyle(fontFamily: 'monospace')),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        savedIp = null;
                      });
                    },
                    child: const Text('Change IP Address'),
                  ),
                ],
              ),
            ),
          );
        }

        return HomeScreen(
          apiService: ApiService(baseUrl: 'http://$savedIp'),
          esp32Ip: savedIp!,
          onIpChange: () {
            setState(() {
              savedIp = null;
            });
          },
        );
      },
    );
  }
}