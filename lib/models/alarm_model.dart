class AlarmStatus {
  final bool armed;
  final bool alarm;
  final int volume;
  final String time;
  final String wifiMode;
  final String ip;
  final List<Zone> zones;
  final Schedule schedule;

  AlarmStatus({
    required this.armed,
    required this.alarm,
    required this.volume,
    required this.time,
    required this.wifiMode,
    required this.ip,
    required this.zones,
    required this.schedule,
  });

  factory AlarmStatus.fromJson(Map<String, dynamic> json) {
    var zonesList = json['zones'] as List;
    List<Zone> zones = zonesList.map((i) => Zone.fromJson(i)).toList();

    return AlarmStatus(
      armed: json['armed'] ?? false,
      alarm: json['alarm'] ?? false,
      volume: json['volume'] ?? 20,
      time: json['time'] ?? "00:00",
      wifiMode: json['wifiMode'] ?? "AP Mode",
      ip: json['ip'] ?? "0.0.0.0",
      zones: zones,
      schedule: Schedule.fromJson(json['schedule']),
    );
  }
}

class Zone {
  final int id;
  final bool paired;
  final String name;

  Zone({required this.id, required this.paired, required this.name});

  factory Zone.fromJson(Map<String, dynamic> json) {
    return Zone(
      id: json['id'] ?? 0,
      paired: json['paired'] ?? false,
      name: json['name'] ?? "Zone ${json['id']}",
    );
  }
}

class Schedule {
  final int start;
  final int end;

  Schedule({required this.start, required this.end});

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      start: json['start'] ?? 5,
      end: json['end'] ?? 21,
    );
  }
}