import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/alarm_model.dart';

class HomeScreen extends StatefulWidget {
  final ApiService apiService;
  final String esp32Ip;
  final VoidCallback onIpChange;

  const HomeScreen({
    super.key,
    required this.apiService,
    required this.esp32Ip,
    required this.onIpChange,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<AlarmStatus> _statusFuture;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  void _refreshStatus() {
    setState(() {
      _isRefreshing = true;
      _statusFuture = widget.apiService.getStatus();
    });
    _statusFuture.whenComplete(() {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    });
  }

  Future<void> _armSystem() async {
    final success = await widget.apiService.armSystem();
    if (success && mounted) {
      _refreshStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System Armed 🔒')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to arm system', style: TextStyle(color: Colors.red))),
      );
    }
  }

  Future<void> _disarmSystem() async {
    final success = await widget.apiService.disarmSystem();
    if (success && mounted) {
      _refreshStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System Disarmed 🔓')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to disarm system', style: TextStyle(color: Colors.red))),
      );
    }
  }

  Future<void> _testSiren() async {
    await widget.apiService.testSiren();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing Siren 🔊')),
    );
  }

  Future<void> _pairZone(int zone) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Pairing Sensor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Trigger Zone ${zone + 1} sensor now...'),
          ],
        ),
      ),
    );

    final success = await widget.apiService.pairZone(zone);
    if (!mounted) return;
    Navigator.pop(context);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zone ${zone + 1} paired successfully!')),
      );
      _refreshStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zone ${zone + 1} pairing failed', style: const TextStyle(color: Colors.red))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Temple Alarm'),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.esp32Ip,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Settings'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('ESP32 IP Address:'),
                      const SizedBox(height: 8),
                      Text(widget.esp32Ip, style: const TextStyle(fontFamily: 'monospace')),
                      const SizedBox(height: 16),
                      const Text('Connection Status: Connected'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: widget.onIpChange,
                      child: const Text('Change IP'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshStatus(),
        child: FutureBuilder<AlarmStatus>(
          future: _statusFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !_isRefreshing) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshStatus,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final status = snapshot.data!;
            final isArmed = status.armed;
            final isAlarm = status.alarm;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Status Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isAlarm
                              ? [Colors.red.shade700, Colors.red.shade900]
                              : isArmed
                                  ? [Colors.red.shade400, Colors.red.shade700]
                                  : [Colors.green.shade400, Colors.green.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isAlarm
                                ? Icons.warning_amber_rounded
                                : isArmed
                                    ? Icons.lock
                                    : Icons.lock_open,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isAlarm
                                ? 'ALARM ACTIVE!'
                                : isArmed
                                    ? 'SYSTEM ARMED'
                                    : 'SYSTEM DISARMED',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            status.time,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!isAlarm) ...[
                                ElevatedButton.icon(
                                  onPressed: isArmed ? null : _armSystem,
                                  icon: const Icon(Icons.lock),
                                  label: const Text('ARM'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: isArmed ? Colors.grey : Colors.red,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: !isArmed ? null : _disarmSystem,
                                  icon: const Icon(Icons.lock_open),
                                  label: const Text('DISARM'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: !isArmed ? Colors.grey : Colors.green,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _testSiren,
                                icon: const Icon(Icons.volume_up),
                                label: const Text('TEST'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Volume Control
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.volume_up),
                              SizedBox(width: 8),
                              Text('Volume Control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.volume_down, size: 20),
                              Expanded(
                                child: Slider(
                                  value: status.volume.toDouble(),
                                  min: 0,
                                  max: 30,
                                  divisions: 30,
                                  onChanged: (value) async {
                                    await widget.apiService.setVolume(value.toInt());
                                    _refreshStatus();
                                  },
                                ),
                              ),
                              const Icon(Icons.volume_up, size: 20),
                            ],
                          ),
                          Center(
                            child: Text(
                              '${status.volume} / 30',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Zones Grid
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.sensors),
                              SizedBox(width: 8),
                              Text('Security Zones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.2,
                            ),
                            itemCount: status.zones.length,
                            itemBuilder: (context, index) {
                              final zone = status.zones[index];
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: zone.paired ? Colors.green : Colors.grey,
                                    width: 2,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () => _pairZone(zone.id),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          zone.paired ? Icons.check_circle : Icons.add_circle_outline,
                                          color: zone.paired ? Colors.green : Colors.grey,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          zone.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: zone.paired ? Colors.green.shade100 : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            zone.paired ? 'Paired' : 'Tap to Pair',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: zone.paired ? Colors.green.shade800 : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const AlertDialog(
                                    title: Text('Pairing Remote'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text('Press ARM then DISARM on remote...'),
                                      ],
                                    ),
                                  ),
                                );
                                final success = await widget.apiService.pairRemote();
                                if (!mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success ? 'Remote paired!' : 'Remote pairing failed'),
                                    backgroundColor: success ? Colors.green : Colors.red,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.gamepad),
                              label: const Text('Pair New Remote'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Schedule Info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Announcement Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  '${status.schedule.start}:00 - ${status.schedule.end}:00',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.notifications_active, color: Colors.blue),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}