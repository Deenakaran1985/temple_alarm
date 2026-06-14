import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  final Function(String ip, String password) onLoggedIn;

  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ipCtrl = TextEditingController(text: '192.168.4.1');
  final _pwdCtrl = TextEditingController();
  bool _isConnecting = false;
  bool _obscure = true;
  String? _error;
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('esp32_ip') ?? '192.168.4.1';
    if (mounted) setState(() => _ipCtrl.text = ip);
    _fetchDeviceId(ip);
  }

  Future<void> _fetchDeviceId(String ip) async {
    if (ip.isEmpty) return;
    try {
      final status = await ApiService(baseUrl: 'http://$ip').getStatus();
      if (mounted) setState(() => _deviceId = status.deviceID);
    } catch (_) {
      if (mounted) setState(() => _deviceId = 'Unreachable');
    }
  }

  Future<void> _connect() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) {
      setState(() => _error = 'Enter the ESP32 IP address');
      return;
    }
    setState(() {
      _isConnecting = true;
      _error = null;
    });

    final ok = await ApiService(baseUrl: 'http://$ip').login(_pwdCtrl.text);
    if (!mounted) return;

    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('esp32_ip', ip);
      await prefs.setString('esp32_pwd', _pwdCtrl.text);
      widget.onLoggedIn(ip, _pwdCtrl.text);
    } else {
      setState(() {
        _isConnecting = false;
        _error = 'Incorrect password or device unreachable';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f13),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a0a2e), Color(0xFF0a1a2e)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1a24),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2a2a3a)),
                    ),
                    child: const Icon(Icons.temple_hindu,
                        size: 48, color: Color(0xFFf59e0b)),
                  ),
                  const SizedBox(height: 20),
                  const Text('Temple Alarm',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('Security Management System',
                      style:
                          TextStyle(color: Color(0xFF8888aa), fontSize: 13)),
                  const SizedBox(height: 40),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field(
                          ctrl: _ipCtrl,
                          label: 'ESP32 IP Address',
                          hint: '192.168.4.1',
                          icon: Icons.wifi,
                          keyboard: TextInputType.number,
                          onChanged: _fetchDeviceId,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          ctrl: _pwdCtrl,
                          label: 'Password',
                          hint: 'Enter admin password',
                          icon: Icons.lock_outline,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF8888aa),
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          onSubmit: (_) => _connect(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Color(0xFFf87171), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            color: Color(0xFFf87171),
                                            fontSize: 13))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isConnecting ? null : _connect,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFf59e0b),
                              foregroundColor: Colors.black,
                              disabledBackgroundColor:
                                  const Color(0xFF8a6a20),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isConnecting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.black))
                                : const Text('Sign In  →',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                          ),
                        ),
                        if (_deviceId.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111118),
                              border: Border.all(
                                  color: const Color(0xFF2a2a3a)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Device: ',
                                    style: TextStyle(
                                        color: Color(0xFF8888aa),
                                        fontSize: 11)),
                                Text(_deviceId,
                                    style: const TextStyle(
                                        color: Color(0xFFf59e0b),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Connect to WiFi: TempleAlarm  •  Default IP: 192.168.4.1',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Color(0xFF555570), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a24),
          border: Border.all(color: const Color(0xFF2a2a3a)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: child,
      );

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboard,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmit,
  }) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboard,
        onChanged: onChanged,
        onSubmitted: onSubmit,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              const TextStyle(color: Color(0xFF8888aa), fontSize: 12),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF444460)),
          prefixIcon: Icon(icon, color: const Color(0xFF8888aa), size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFF111118),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2a2a3a))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2a2a3a))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFf59e0b), width: 1.5)),
        ),
      );
}
