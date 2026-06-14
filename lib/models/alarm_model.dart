class SongSlot {
  int fromH, fromM, toH, toM, startTrack;
  bool enabled;

  SongSlot({
    required this.fromH,
    required this.fromM,
    required this.toH,
    required this.toM,
    required this.startTrack,
    required this.enabled,
  });

  factory SongSlot.fromJson(Map<String, dynamic> json) => SongSlot(
        fromH: (json['fh'] as num?)?.toInt() ?? 5,
        fromM: (json['fm'] as num?)?.toInt() ?? 0,
        toH: (json['th'] as num?)?.toInt() ?? 9,
        toM: (json['tm'] as num?)?.toInt() ?? 0,
        startTrack: (json['tr'] as num?)?.toInt() ?? 1,
        enabled: ((json['en'] as num?)?.toInt() ?? 0) == 1,
      );

  static SongSlot defaults(int index) {
    const d = [
      [5, 0, 9, 0, 1],
      [11, 0, 13, 0, 23],
      [17, 0, 21, 0, 40],
    ];
    return SongSlot(
      fromH: d[index][0],
      fromM: d[index][1],
      toH: d[index][2],
      toM: d[index][3],
      startTrack: d[index][4],
      enabled: false,
    );
  }

  SongSlot copyWith({
    int? fromH,
    int? fromM,
    int? toH,
    int? toM,
    int? startTrack,
    bool? enabled,
  }) =>
      SongSlot(
        fromH: fromH ?? this.fromH,
        fromM: fromM ?? this.fromM,
        toH: toH ?? this.toH,
        toM: toM ?? this.toM,
        startTrack: startTrack ?? this.startTrack,
        enabled: enabled ?? this.enabled,
      );
}

class Zone {
  final int id;
  final bool paired;
  final bool triggered;
  final String name;

  Zone({
    required this.id,
    required this.paired,
    this.triggered = false,
    required this.name,
  });

  factory Zone.fromJson(Map<String, dynamic> json) => Zone(
        id: (json['id'] as num?)?.toInt() ?? 0,
        paired: json['paired'] as bool? ?? false,
        triggered: json['triggered'] as bool? ?? false,
        name: json['name'] as String? ?? 'Zone ${json['id']}',
      );
}

class WifiNetwork {
  final String ssid;
  final int rssi;
  final bool secure;

  WifiNetwork({required this.ssid, required this.rssi, required this.secure});

  factory WifiNetwork.fromJson(Map<String, dynamic> json) => WifiNetwork(
        ssid: json['ssid'] as String? ?? '',
        rssi: (json['rssi'] as num?)?.toInt() ?? -100,
        secure: json['secure'] as bool? ?? false,
      );

  int get bars {
    if (rssi >= -50) return 4;
    if (rssi >= -65) return 3;
    if (rssi >= -75) return 2;
    return 1;
  }
}

class AlarmStatus {
  final String deviceID;
  final bool armed, alarm, music, ntpEnabled, hourly, muteArm, apMode;
  final int volume, alarmDur;
  final String time, date, ip;
  final String duckDomain;
  final List<Zone> zones;
  final List<int> remote;
  final List<SongSlot> slots;

  AlarmStatus({
    required this.deviceID,
    required this.armed,
    required this.alarm,
    required this.music,
    required this.ntpEnabled,
    required this.hourly,
    required this.muteArm,
    required this.apMode,
    required this.volume,
    required this.alarmDur,
    required this.time,
    required this.date,
    required this.ip,
    this.duckDomain = '',
    required this.zones,
    required this.remote,
    required this.slots,
  });

  factory AlarmStatus.fromJson(Map<String, dynamic> json) {
    final zonesList = (json['zones'] as List? ?? [])
        .map((z) => Zone.fromJson(z as Map<String, dynamic>))
        .toList();

    // remote is [{btn, code, paired}, …] — extract the code int from each object
    final remoteList = (json['remote'] as List? ?? []).map((r) {
      final m = r as Map<String, dynamic>;
      return (m['code'] as num?)?.toInt() ?? 0;
    }).toList();

    final rawSlots = (json['slots'] as List? ?? [])
        .map((s) => SongSlot.fromJson(s as Map<String, dynamic>))
        .toList();
    while (rawSlots.length < 3) {
      rawSlots.add(SongSlot.defaults(rawSlots.length));
    }

    return AlarmStatus(
      deviceID: json['deviceID'] as String? ?? 'TALM-??????',
      armed: json['armed'] as bool? ?? false,
      alarm: json['alarm'] as bool? ?? false,
      music: json['music'] as bool? ?? false,
      ntpEnabled: json['ntpEnabled'] as bool? ?? false,
      hourly: json['hourly'] as bool? ?? false,
      muteArm: json['muteArm'] as bool? ?? false,
      apMode: json['apMode'] as bool? ?? true,
      volume: (json['volume'] as num?)?.toInt() ?? 20,
      alarmDur: (json['alarmDur'] as num?)?.toInt() ?? 30,
      time: json['time'] as String? ?? '00:00:00',
      date: json['date'] as String? ?? '--',
      ip: json['ip'] as String? ?? '0.0.0.0',
      duckDomain: json['duckDomain'] as String? ?? '',
      zones: zonesList,
      remote: remoteList,
      slots: rawSlots,
    );
  }
}
