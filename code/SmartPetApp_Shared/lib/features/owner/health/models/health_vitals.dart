class HealthVitals {
  final int heartRate;
  final double temperature;
  final int spo2; 
  final DateTime timestamp;

  HealthVitals({
    required this.heartRate,
    required this.temperature,
    required this.spo2,
    required this.timestamp,
  });

factory HealthVitals.fromJson(Map<String, dynamic> json) {
  String ts = json['timestamp'] as String;
  // ESP32 uses dashes in time part (e.g. 2026-03-04T13-36-17), fix to valid ISO
  if (ts.length >= 19 && ts[13] == '-') {
    ts = ts.substring(0, 11) + ts.substring(11).replaceAll('-', ':');
  }

  return HealthVitals(
    heartRate: (json['heartRate'] as num).toInt(),
    temperature: (json['temperature'] as num).toDouble(),
    spo2:        (json['spo2']        as num? ?? 0).toInt(),
    timestamp: DateTime.parse(ts).toLocal(),
  );
}

  Map<String, dynamic> toJson() {
    return {
      'heartRate': heartRate,
      'temperature': temperature,
      'spo2':        spo2,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

enum VitalStatus { normal, caution, danger }

extension HealthVitalsStatus on HealthVitals {
  VitalStatus get heartRateStatus {
    if (heartRate >= 60 && heartRate <= 140) return VitalStatus.normal;
    if (heartRate >= 40 && heartRate <= 160) return VitalStatus.caution;
    return VitalStatus.danger;
  }

  VitalStatus get temperatureStatus {
    if (temperature >= 38.0 && temperature <= 39.2) return VitalStatus.normal;
    if (temperature >= 37.2 && temperature <= 40.0) return VitalStatus.caution;
    return VitalStatus.danger;
  }

  VitalStatus get spo2Status {
    if (spo2 >= 95) return VitalStatus.normal;
    if (spo2 >= 90) return VitalStatus.caution;
    return VitalStatus.danger;
  }
}