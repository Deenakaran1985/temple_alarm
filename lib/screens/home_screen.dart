import 'dart:async';
import 'package:flutter/material.dart';
import '../models/alarm_model.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main scaffold
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final ApiService apiService;
  final String esp32Ip;
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.apiService,
    required this.esp32Ip,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AlarmStatus? _status;
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final s = await widget.apiService.getStatus();
      if (mounted) setState(() { _status = s; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? const Color(0xFF991b1b) : const Color(0xFF14532d),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => _darkDialog(
        title: 'Disconnect',
        content: 'Disconnect from ${widget.esp32Ip}?',
        actions: [
          _dialogBtn('Cancel', () => Navigator.pop(ctx)),
          _dialogBtn('Disconnect', () {
            Navigator.pop(ctx);
            widget.onLogout();
          }, color: Colors.red),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFF0f0f13),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1a1a24),
          title: Row(
            children: [
              const Icon(Icons.temple_hindu,
                  color: Color(0xFFf59e0b), size: 20),
              const SizedBox(width: 8),
              const Text('Temple Alarm',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Spacer(),
              if (_status != null) _statusChip(_status!),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF8888aa), size: 20),
              onPressed: _confirmLogout,
            ),
          ],
          bottom: TabBar(
            indicatorColor: const Color(0xFFf59e0b),
            indicatorWeight: 3,
            labelColor: const Color(0xFFf59e0b),
            unselectedLabelColor: const Color(0xFF8888aa),
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Dashboard'),
              Tab(icon: Icon(Icons.sensors, size: 18), text: 'Zones'),
              Tab(icon: Icon(Icons.music_note, size: 18), text: 'Audio'),
              Tab(icon: Icon(Icons.settings, size: 18), text: 'Settings'),
              Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Log'),
            ],
          ),
        ),
        body: _loading && _status == null
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFf59e0b)))
            : _error != null && _status == null
                ? _buildError()
                : RefreshIndicator(
                    color: const Color(0xFFf59e0b),
                    onRefresh: _refresh,
                    child: TabBarView(children: [
                      _DashboardTab(
                          status: _status!,
                          api: widget.apiService,
                          onRefresh: _refresh,
                          onSnack: _snack),
                      _ZonesTab(
                          status: _status!,
                          api: widget.apiService,
                          onRefresh: _refresh,
                          onSnack: _snack),
                      _AudioTab(
                          status: _status!,
                          api: widget.apiService,
                          onRefresh: _refresh,
                          onSnack: _snack),
                      _SettingsTab(
                          status: _status!,
                          api: widget.apiService,
                          onRefresh: _refresh,
                          onSnack: _snack),
                      _LogTab(api: widget.apiService, onSnack: _snack),
                    ]),
                  ),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error ?? 'Connection error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf59e0b),
                  foregroundColor: Colors.black),
            ),
          ]),
        ),
      );

  Widget _statusChip(AlarmStatus s) {
    Color bg;
    String label;
    if (s.alarm) {
      bg = const Color(0xFF991b1b);
      label = '⚠ ALARM';
    } else if (s.armed) {
      bg = const Color(0xFF92400e);
      label = '🔒 ARMED';
    } else {
      bg = const Color(0xFF14532d);
      label = '✓ SAFE';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Tab
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final AlarmStatus status;
  final ApiService api;
  final VoidCallback onRefresh;
  final void Function(String, {bool error}) onSnack;

  const _DashboardTab(
      {required this.status,
      required this.api,
      required this.onRefresh,
      required this.onSnack});

  Future<void> _action(
      BuildContext ctx, Future<bool> Function() fn, String ok) async {
    final res = await fn();
    onSnack(res ? ok : 'Failed', error: !res);
    if (res) onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final isAlarm = status.alarm;
    final isArmed = status.armed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Status Hero ──
        _statusHero(context, isAlarm, isArmed),
        const SizedBox(height: 16),
        // ── Controls ──
        _card(
          child: Column(children: [
            const _SectionHeader(icon: Icons.security, label: 'Alarm Control'),
            const SizedBox(height: 16),
            if (isAlarm)
              _fullBtn(
                label: 'STOP ALARM',
                icon: Icons.stop_circle,
                color: Colors.red,
                onTap: () =>
                    _action(context, api.stopAlarm, 'Alarm stopped'),
              )
            else ...[
              Row(children: [
                Expanded(
                  child: _ctrlBtn(
                    label: 'ARM',
                    icon: Icons.lock,
                    color: const Color(0xFFf59e0b),
                    enabled: !isArmed,
                    onTap: () =>
                        _action(context, api.arm, 'System armed'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ctrlBtn(
                    label: 'DISARM',
                    icon: Icons.lock_open,
                    color: Colors.green,
                    enabled: isArmed,
                    onTap: () =>
                        _action(context, api.disarm, 'System disarmed'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              _fullBtn(
                label: 'PANIC',
                icon: Icons.warning_amber_rounded,
                color: Colors.red,
                onTap: () => _confirmPanic(context),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        // ── Info Card ──
        _card(
          child: Column(children: [
            const _SectionHeader(icon: Icons.info_outline, label: 'Device Info'),
            const SizedBox(height: 12),
            _infoRow('Device ID', status.deviceID, mono: true),
            _infoRow('Time', '${status.date}  ${status.time}'),
            _infoRow('IP Address', status.ip),
            _infoRow('WiFi Mode',
                status.apMode ? 'Access Point (AP)' : 'Station (WiFi)'),
            _infoRow('Music',
                status.music ? 'Playing  ♪' : 'Stopped'),
          ]),
        ),
      ]),
    );
  }

  Widget _statusHero(BuildContext ctx, bool isAlarm, bool isArmed) {
    final List<Color> colors;
    final String label;
    final IconData icon;
    if (isAlarm) {
      colors = [const Color(0xFF7f1d1d), const Color(0xFF991b1b)];
      label = 'ALARM ACTIVE!';
      icon = Icons.warning_amber_rounded;
    } else if (isArmed) {
      colors = [const Color(0xFF78350f), const Color(0xFF92400e)];
      label = 'SYSTEM ARMED';
      icon = Icons.lock;
    } else {
      colors = [const Color(0xFF14532d), const Color(0xFF166534)];
      label = 'SYSTEM DISARMED';
      icon = Icons.lock_open;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Icon(icon, color: Colors.white, size: 52),
        const SizedBox(height: 12),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(status.time,
            style: const TextStyle(color: Colors.white70, fontSize: 16)),
      ]),
    );
  }

  void _confirmPanic(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (c) => _darkDialog(
        title: 'Trigger PANIC?',
        content: 'This will immediately activate the alarm siren and relay.',
        actions: [
          _dialogBtn('Cancel', () => Navigator.pop(c)),
          _dialogBtn('PANIC', () {
            Navigator.pop(c);
            _action(ctx, api.panic, 'Panic triggered!');
          }, color: Colors.red),
        ],
      ),
    );
  }

  Widget _ctrlBtn({
    required String label,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) =>
      ElevatedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : const Color(0xFF2a2a3a),
          foregroundColor: enabled ? Colors.white : const Color(0xFF555570),
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );

  Widget _fullBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          label: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _infoRow(String label, String value, {bool mono = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF8888aa), fontSize: 13)),
            Text(value,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: mono ? 'monospace' : null)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Zones Tab
// ─────────────────────────────────────────────────────────────────────────────

class _ZonesTab extends StatelessWidget {
  final AlarmStatus status;
  final ApiService api;
  final VoidCallback onRefresh;
  final void Function(String, {bool error}) onSnack;

  const _ZonesTab(
      {required this.status,
      required this.api,
      required this.onRefresh,
      required this.onSnack});

  Future<void> _pair(BuildContext ctx, Zone zone) async {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => _darkDialog(
        title: 'Pairing Zone ${zone.id + 1}',
        content:
            'Trigger the sensor for Zone ${zone.id + 1} now.\n\n(Waiting up to 15 seconds…)',
        actions: [],
        showProgress: true,
      ),
    );
    final ok = await api.pairZone(zone.id);
    if (!ctx.mounted) return;
    Navigator.of(ctx, rootNavigator: true).pop();
    onSnack(
        ok
            ? '${zone.name} paired!'
            : 'Pairing failed – sensor not triggered',
        error: !ok);
    if (ok) onRefresh();
  }

  Future<void> _unpair(BuildContext ctx, Zone zone) async {
    final ok = await api.unpairZone(zone.id);
    onSnack(ok ? '${zone.name} unpaired' : 'Unpair failed', error: !ok);
    if (ok) onRefresh();
  }

  void _rename(BuildContext ctx, Zone zone) {
    final ctrl = TextEditingController(text: zone.name);
    showDialog(
      context: ctx,
      builder: (c) => _darkDialog(
        title: 'Rename Zone ${zone.id + 1}',
        content: null,
        contentWidget: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 15,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Zone name',
            hintStyle: TextStyle(color: Color(0xFF555570)),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          _dialogBtn('Cancel', () => Navigator.pop(c)),
          _dialogBtn('Save', () async {
            Navigator.pop(c);
            final ok = await api.setZoneName(zone.id, ctrl.text.trim());
            onSnack(ok ? 'Name saved' : 'Failed', error: !ok);
            if (ok) onRefresh();
          }, color: const Color(0xFFf59e0b)),
        ],
      ),
    );
  }

  void _pairRemote(BuildContext ctx) async {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => _darkDialog(
        title: 'Pairing Remote',
        content: 'Press any button on the remote control now…',
        actions: [],
        showProgress: true,
      ),
    );
    final ok = await api.pairRemote();
    if (!ctx.mounted) return;
    Navigator.of(ctx, rootNavigator: true).pop();
    onSnack(ok ? 'Remote paired!' : 'Pairing failed', error: !ok);
    if (ok) onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _card(
          child: Column(children: [
            const _SectionHeader(
                icon: Icons.sensors, label: 'Security Zones'),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: status.zones.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (ctx, i) =>
                  _zoneCard(ctx, status.zones[i]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(children: [
            const _SectionHeader(
                icon: Icons.settings_remote, label: 'Remote Control'),
            const SizedBox(height: 12),
            Row(
              children: List.generate(status.remote.length, (i) {
                final code = status.remote[i];
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: code != 0
                          ? const Color(0xFF14532d)
                          : const Color(0xFF1a1a24),
                      border: Border.all(
                          color: code != 0
                              ? const Color(0xFF16a34a)
                              : const Color(0xFF2a2a3a)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(children: [
                      Icon(
                          code != 0
                              ? Icons.settings_remote
                              : Icons.radio_button_unchecked,
                          color: code != 0
                              ? Colors.green
                              : const Color(0xFF555570),
                          size: 22),
                      const SizedBox(height: 4),
                      Text('R${i + 1}',
                          style: TextStyle(
                              color: code != 0
                                  ? Colors.white
                                  : const Color(0xFF555570),
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pairRemote(context),
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Pair Remote'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFf59e0b),
                    side:
                        const BorderSide(color: Color(0xFFf59e0b)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await api.unpairRemote();
                    onSnack(ok ? 'Remote unpaired' : 'Failed',
                        error: !ok);
                    if (ok) onRefresh();
                  },
                  icon: const Icon(Icons.link_off, size: 16),
                  label: const Text('Unpair'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _zoneCard(BuildContext ctx, Zone zone) {
    final paired = zone.paired;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        border: Border.all(
            color: paired
                ? const Color(0xFF16a34a)
                : const Color(0xFF2a2a3a),
            width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: paired ? null : () => _pair(ctx, zone),
        onLongPress: () => _showZoneMenu(ctx, zone),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                paired ? Icons.check_circle : Icons.add_circle_outline,
                color: paired ? Colors.green : const Color(0xFF555570),
                size: 30,
              ),
              const SizedBox(height: 8),
              Text(
                zone.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: paired
                      ? const Color(0xFF14532d)
                      : const Color(0xFF1a1a24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  paired ? 'Paired' : 'Tap to Pair',
                  style: TextStyle(
                      fontSize: 10,
                      color: paired
                          ? Colors.green
                          : const Color(0xFF8888aa)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showZoneMenu(BuildContext ctx, Zone zone) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF1a1a24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(zone.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 20),
          if (!zone.paired)
            ListTile(
              leading: const Icon(Icons.sensors, color: Color(0xFFf59e0b)),
              title: const Text('Pair Sensor',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(c);
                _pair(ctx, zone);
              },
            ),
          if (zone.paired)
            ListTile(
              leading: const Icon(Icons.link_off, color: Colors.red),
              title: const Text('Unpair Sensor',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(c);
                _unpair(ctx, zone);
              },
            ),
          ListTile(
            leading: const Icon(Icons.edit, color: Color(0xFF8888aa)),
            title: const Text('Rename Zone',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(c);
              _rename(ctx, zone);
            },
          ),
          if (zone.paired)
            ListTile(
              leading: const Icon(Icons.sensors, color: Color(0xFFf59e0b)),
              title: const Text('Re-pair Sensor',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(c);
                _pair(ctx, zone);
              },
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio Tab
// ─────────────────────────────────────────────────────────────────────────────

class _AudioTab extends StatefulWidget {
  final AlarmStatus status;
  final ApiService api;
  final VoidCallback onRefresh;
  final void Function(String, {bool error}) onSnack;

  const _AudioTab(
      {required this.status,
      required this.api,
      required this.onRefresh,
      required this.onSnack});

  @override
  State<_AudioTab> createState() => _AudioTabState();
}

class _AudioTabState extends State<_AudioTab> {
  late List<SongSlot> _slots;
  final _trackCtrl = TextEditingController(text: '1');
  bool _savingSlots = false;

  static const _slotNames = ['Morning', 'Noon', 'Evening'];

  @override
  void initState() {
    super.initState();
    _slots = widget.status.slots
        .map((s) => s.copyWith())
        .toList();
  }

  @override
  void dispose() {
    _trackCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSlots() async {
    setState(() => _savingSlots = true);
    final ok = await widget.api.saveSongSlots(_slots);
    setState(() => _savingSlots = false);
    widget.onSnack(ok ? 'Song slots saved' : 'Save failed', error: !ok);
    if (ok) widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Volume ──
        _card(
          child: Column(children: [
            const _SectionHeader(
                icon: Icons.volume_up, label: 'Volume Control'),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.volume_down,
                  color: Color(0xFF8888aa), size: 20),
              Expanded(
                child: Slider(
                  value: widget.status.volume.toDouble(),
                  min: 0,
                  max: 30,
                  divisions: 30,
                  activeColor: const Color(0xFFf59e0b),
                  inactiveColor: const Color(0xFF2a2a3a),
                  label: widget.status.volume.toString(),
                  onChanged: (v) async {
                    await widget.api.setVolume(v.toInt());
                    widget.onRefresh();
                  },
                ),
              ),
              const Icon(Icons.volume_up,
                  color: Color(0xFF8888aa), size: 20),
            ]),
            Text('${widget.status.volume} / 30',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 16),
        // ── Play Track ──
        _card(
          child: Column(children: [
            const _SectionHeader(
                icon: Icons.play_circle_outline, label: 'Play Track'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _trackCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Track number',
                    labelStyle: TextStyle(color: Color(0xFF8888aa)),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  final t = int.tryParse(_trackCtrl.text) ?? 1;
                  final ok = await widget.api.playTrack(t);
                  widget.onSnack(
                      ok ? 'Playing track $t' : 'Failed',
                      error: !ok);
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf59e0b),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await widget.api.stopMusic();
                  widget.onSnack(
                      ok ? 'Music stopped' : 'Failed',
                      error: !ok);
                },
                icon: const Icon(Icons.stop, size: 18),
                label: const Text('Stop'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        // ── Song Slots ──
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                  icon: Icons.schedule, label: 'Song Schedule (3 Slots)'),
              const SizedBox(height: 4),
              const Text(
                  'Songs play automatically during these time windows.',
                  style: TextStyle(
                      color: Color(0xFF8888aa), fontSize: 12)),
              const SizedBox(height: 16),
              ...List.generate(_slots.length, (i) => _slotCard(i)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _savingSlots ? null : _saveSlots,
                  icon: _savingSlots
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.save, size: 18),
                  label: const Text('Save Song Schedule',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf59e0b),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _slotCard(int i) {
    final s = _slots[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        border: Border.all(
            color: s.enabled
                ? const Color(0xFFd97706)
                : const Color(0xFF2a2a3a)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_slotNames[i],
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const Spacer(),
          Switch(
            value: s.enabled,
            activeColor: const Color(0xFFf59e0b),
            onChanged: (v) =>
                setState(() => _slots[i] = s.copyWith(enabled: v)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _timeField(
              label: 'From',
              h: s.fromH,
              m: s.fromM,
              onChanged: (h, m) => setState(
                  () => _slots[i] = s.copyWith(fromH: h, fromM: m)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('→',
                style: TextStyle(color: Color(0xFF8888aa), fontSize: 18)),
          ),
          Expanded(
            child: _timeField(
              label: 'To',
              h: s.toH,
              m: s.toM,
              onChanged: (h, m) =>
                  setState(() => _slots[i] = s.copyWith(toH: h, toM: m)),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              controller:
                  TextEditingController(text: s.startTrack.toString()),
              onChanged: (v) {
                final t = int.tryParse(v);
                if (t != null) {
                  setState(() => _slots[i] = s.copyWith(startTrack: t));
                }
              },
              decoration: InputDecoration(
                labelText: 'Track',
                labelStyle:
                    const TextStyle(color: Color(0xFF8888aa), fontSize: 11),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _timeField({
    required String label,
    required int h,
    required int m,
    required void Function(int h, int m) onChanged,
  }) =>
      InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: h, minute: m),
            builder: (ctx, child) => Theme(
              data: ThemeData.dark(),
              child: child!,
            ),
          );
          if (picked != null) onChanged(picked.hour, picked.minute);
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a24),
            border: Border.all(color: const Color(0xFF2a2a3a)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF8888aa), fontSize: 10)),
            const SizedBox(height: 2),
            Text(
              '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Tab
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTab extends StatefulWidget {
  final AlarmStatus status;
  final ApiService api;
  final String esp32Ip;
  final VoidCallback onRefresh;
  final void Function(String, {bool error}) onSnack;

  const _SettingsTab(
      {required this.status,
      required this.api,
      required this.esp32Ip,
      required this.onRefresh,
      required this.onSnack});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late bool _ntpEnabled;
  late bool _hourly;
  late bool _muteArm;
  late int _alarmDur;
  final _durCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  List<TextEditingController> _zoneNameCtrls = [];

  List<WifiNetwork> _networks = [];
  bool _scanning = false;
  String? _selectedSsid;
  final _wifiPwdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ntpEnabled = widget.status.ntpEnabled;
    _hourly = widget.status.hourly;
    _muteArm = widget.status.muteArm;
    _alarmDur = widget.status.alarmDur;
    _durCtrl.text = _alarmDur.toString();
    _zoneNameCtrls = widget.status.zones
        .map((z) => TextEditingController(text: z.name))
        .toList();
  }

  @override
  void dispose() {
    _durCtrl.dispose();
    _newPwdCtrl.dispose();
    _pinCtrl.dispose();
    _wifiPwdCtrl.dispose();
    for (final c in _zoneNameCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scanWifi() async {
    setState(() { _scanning = true; _networks = []; });
    final nets = await widget.api.scanWifi();
    if (mounted) setState(() { _networks = nets; _scanning = false; });
  }

  Future<void> _saveSettings() async {
    final dur = int.tryParse(_durCtrl.text) ?? _alarmDur;
    final ok = await widget.api.saveSettings(
      alarmDur: dur,
      ntpEnabled: _ntpEnabled,
      hourly: _hourly,
      muteArm: _muteArm,
    );
    widget.onSnack(ok ? 'Settings saved' : 'Save failed', error: !ok);
    if (ok) widget.onRefresh();
  }

  Future<void> _saveZoneNames() async {
    int saved = 0;
    for (int i = 0; i < _zoneNameCtrls.length; i++) {
      final name = _zoneNameCtrls[i].text.trim();
      if (name.isNotEmpty &&
          name != widget.status.zones[i].name) {
        final ok = await widget.api.setZoneName(i, name);
        if (ok) saved++;
      }
    }
    widget.onSnack(
        saved > 0 ? 'Zone names saved ($saved)' : 'No changes',
        error: false);
    widget.onRefresh();
  }

  Future<void> _changePassword() async {
    if (_newPwdCtrl.text.isEmpty || _pinCtrl.text.isEmpty) {
      widget.onSnack('Fill in new password and PIN', error: true);
      return;
    }
    final ok = await widget.api.changePassword(
        _newPwdCtrl.text, _pinCtrl.text);
    widget.onSnack(
        ok ? 'Password changed' : 'Failed – check your PIN',
        error: !ok);
    if (ok) { _newPwdCtrl.clear(); _pinCtrl.clear(); }
  }

  Future<void> _setRtcTime() async {
    final now = DateTime.now();
    final ok = await widget.api.setTime(now);
    widget.onSnack(
        ok ? 'RTC updated to ${now.hour}:${now.minute.toString().padLeft(2, '0')}' : 'Failed',
        error: !ok);
    if (ok) widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── WiFi ──
        _card(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const _SectionHeader(icon: Icons.wifi, label: 'WiFi Connection'),
            const SizedBox(height: 4),
            Text(
              'Current: ${widget.status.apMode ? 'AP Mode (192.168.4.1)' : 'STA (${widget.status.ip})'}',
              style:
                  const TextStyle(color: Color(0xFF8888aa), fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _scanning ? null : _scanWifi,
                icon: _scanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFf59e0b)))
                    : const Icon(Icons.search, size: 16),
                label: Text(_scanning
                    ? 'Scanning…'
                    : 'Scan Networks'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFf59e0b),
                  side: const BorderSide(color: Color(0xFFf59e0b)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_networks.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._networks.map((n) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        n.secure ? Icons.wifi_lock : Icons.wifi,
                        color: _selectedSsid == n.ssid
                            ? const Color(0xFFf59e0b)
                            : const Color(0xFF8888aa)),
                    title: Text(n.ssid,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                    subtitle: Text('${n.rssi} dBm',
                        style: const TextStyle(
                            color: Color(0xFF8888aa), fontSize: 11)),
                    selected: _selectedSsid == n.ssid,
                    onTap: () =>
                        setState(() => _selectedSsid = n.ssid),
                  )),
              if (_selectedSsid != null) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _wifiPwdCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'WiFi Password for $_selectedSsid',
                    labelStyle: const TextStyle(
                        color: Color(0xFF8888aa), fontSize: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await widget.api.connectWifi(
                          _selectedSsid!, _wifiPwdCtrl.text);
                      widget.onSnack(
                          ok
                              ? 'Connecting to $_selectedSsid…'
                              : 'Failed',
                          error: !ok);
                    },
                    icon: const Icon(Icons.wifi, size: 16),
                    label: Text('Connect to $_selectedSsid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFf59e0b),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ]),
        ),
        const SizedBox(height: 16),
        // ── Alarm Settings ──
        _card(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const _SectionHeader(
                icon: Icons.tune, label: 'Alarm Settings'),
            const SizedBox(height: 12),
            TextField(
              controller: _durCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Alarm Duration (seconds)',
                labelStyle: const TextStyle(
                    color: Color(0xFF8888aa), fontSize: 12),
                suffixText: 'sec',
                suffixStyle:
                    const TextStyle(color: Color(0xFF8888aa)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) =>
                  setState(() => _alarmDur = int.tryParse(v) ?? _alarmDur),
            ),
            const SizedBox(height: 12),
            _toggle('Enable NTP Time Sync', _ntpEnabled,
                (v) => setState(() => _ntpEnabled = v)),
            _toggle('Hourly Time Announcement', _hourly,
                (v) => setState(() => _hourly = v)),
            _toggle('Mute Audio When Armed', _muteArm,
                (v) => setState(() => _muteArm = v)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Save Settings',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFf59e0b),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // ── Zone Names ──
        _card(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const _SectionHeader(
                icon: Icons.edit_note, label: 'Zone Names'),
            const SizedBox(height: 12),
            ...List.generate(_zoneNameCtrls.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _zoneNameCtrls[i],
                    maxLength: 15,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Zone ${i + 1}',
                      labelStyle: const TextStyle(
                          color: Color(0xFF8888aa), fontSize: 12),
                      counterStyle: const TextStyle(
                          color: Color(0xFF555570), fontSize: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                )),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saveZoneNames,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save Zone Names'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFf59e0b),
                  side: const BorderSide(color: Color(0xFFf59e0b)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // ── Security ──
        _card(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const _SectionHeader(
                icon: Icons.key, label: 'Change Password & PIN'),
            const SizedBox(height: 12),
            TextField(
              controller: _newPwdCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: const TextStyle(
                    color: Color(0xFF8888aa), fontSize: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Keypad PIN (4-8 digits)',
                labelStyle: const TextStyle(
                    color: Color(0xFF8888aa), fontSize: 12),
                counterStyle: const TextStyle(
                    color: Color(0xFF555570), fontSize: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _changePassword,
                icon: const Icon(Icons.lock_reset, size: 16),
                label: const Text('Change Password'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // ── Clock ──
        _card(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const _SectionHeader(
                icon: Icons.access_time, label: 'Device Clock'),
            const SizedBox(height: 4),
            Text('Current: ${widget.status.date}  ${widget.status.time}',
                style: const TextStyle(
                    color: Color(0xFF8888aa), fontSize: 12)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _setRtcTime,
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sync RTC to Phone Time'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFf59e0b),
                  side: const BorderSide(color: Color(0xFFf59e0b)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // ── System ──
        _card(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const _SectionHeader(
                icon: Icons.developer_board, label: 'System'),
            const SizedBox(height: 4),
            Text('Device: ${widget.status.deviceID}  •  IP: ${widget.esp32Ip}',
                style: const TextStyle(
                    color: Color(0xFF8888aa),
                    fontSize: 11,
                    fontFamily: 'monospace')),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmReboot(context),
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Reboot Device'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  void _confirmReboot(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (c) => _darkDialog(
        title: 'Reboot Device?',
        content:
            'The ESP32 will restart. You may need to reconnect.',
        actions: [
          _dialogBtn('Cancel', () => Navigator.pop(c)),
          _dialogBtn('Reboot', () async {
            Navigator.pop(c);
            await widget.api.reboot();
            widget.onSnack('Rebooting…');
          }, color: Colors.red),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        value: value,
        activeColor: const Color(0xFFf59e0b),
        onChanged: onChanged,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Log Tab
// ─────────────────────────────────────────────────────────────────────────────

class _LogTab extends StatefulWidget {
  final ApiService api;
  final void Function(String, {bool error}) onSnack;

  const _LogTab({required this.api, required this.onSnack});

  @override
  State<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<_LogTab> {
  String _log = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLog();
  }

  Future<void> _fetchLog() async {
    setState(() => _loading = true);
    final log = await widget.api.getLog();
    if (mounted) setState(() { _log = log; _loading = false; });
  }

  Future<void> _clear() async {
    final ok = await widget.api.clearLog();
    widget.onSnack(ok ? 'Log cleared' : 'Failed', error: !ok);
    if (ok) _fetchLog();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Text('Event Log',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const Spacer(),
          IconButton(
            onPressed: _fetchLog,
            icon: const Icon(Icons.refresh, color: Color(0xFFf59e0b)),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Clear log',
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFf59e0b)))
            : _log.isEmpty
                ? const Center(
                    child: Text('No events recorded',
                        style: TextStyle(color: Color(0xFF8888aa))))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111118),
                        border:
                            Border.all(color: const Color(0xFF2a2a3a)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _log,
                          style: const TextStyle(
                              color: Color(0xFF9898aa),
                              fontSize: 12,
                              fontFamily: 'monospace',
                              height: 1.6),
                        ),
                      ),
                    ),
                  ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _card({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a24),
        border: Border.all(color: const Color(0xFF2a2a3a)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );

AlertDialog _darkDialog({
  required String title,
  String? content,
  Widget? contentWidget,
  required List<Widget> actions,
  bool showProgress = false,
}) =>
    AlertDialog(
      backgroundColor: const Color(0xFF1a1a24),
      title:
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      content: contentWidget ??
          Column(mainAxisSize: MainAxisSize.min, children: [
            if (showProgress) ...[
              const CircularProgressIndicator(color: Color(0xFFf59e0b)),
              const SizedBox(height: 16),
            ],
            if (content != null)
              Text(content,
                  style: const TextStyle(color: Color(0xFF8888aa), fontSize: 13)),
          ]),
      actions: actions,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

TextButton _dialogBtn(String label, VoidCallback onTap, {Color? color}) =>
    TextButton(
      onPressed: onTap,
      child: Text(label,
          style: TextStyle(color: color ?? const Color(0xFF8888aa))),
    );

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: const Color(0xFFf59e0b), size: 18),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      ]);
}
