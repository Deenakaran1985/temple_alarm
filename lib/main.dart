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
      title: 'Temple Alarm',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFf59e0b),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0f0f13),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(elevation: 0),
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
  String? _ip;
  String? _pwd;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ip = prefs.getString('esp32_ip');
      _pwd = prefs.getString('esp32_pwd') ?? '';
      _loading = false;
    });
  }

  void _onLoggedIn(String ip, String pwd) =>
      setState(() { _ip = ip; _pwd = pwd; });

  void _onLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('esp32_ip');
    await prefs.remove('esp32_pwd');
    setState(() { _ip = null; _pwd = null; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0f0f13),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFf59e0b)),
        ),
      );
    }

    if (_ip == null) {
      return LoginScreen(onLoggedIn: _onLoggedIn);
    }

    return HomeScreen(
      apiService: ApiService(baseUrl: 'http://$_ip', password: _pwd ?? ''),
      esp32Ip: _ip!,
      onLogout: _onLogout,
    );
  }
}
