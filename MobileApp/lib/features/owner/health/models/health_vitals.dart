class HealthVitals {
  final int respiratoryRate;

  /// Raw temperature as received from the sensor (°C).
  final double temperature;

  /// Fur-type offset applied on top of the raw reading.
  /// 0.0 until the dog profile is loaded.
  final double furOffset;

  final DateTime timestamp;

  HealthVitals({
    required this.respiratoryRate,
    required this.temperature,
    required this.timestamp,
    this.furOffset = 0.0,
  });

  /// The calibrated body temperature estimate shown to the owner.
  double get calibratedTemperature => temperature + furOffset;

  factory HealthVitals.fromJson(Map<String, dynamic> json) {
    // Handle all timestamp formats:
    // 1. int  — Firebase server timestamp (Unix ms) ✅
    // 2. String — ISO from ESP32 firmware
    DateTime parsedTime;
    final rawTs = json['timestamp'];

    if (rawTs is int) {
      // Firebase server timestamp — most accurate ✅
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTs).toLocal();
    } else if (rawTs is String) {
      String ts = rawTs;
      // Fix ESP32 dashes in time part (e.g. 2026-03-04T13-36-17)
      if (ts.length >= 19 && ts[13] == '-') {
        ts = ts.substring(0, 11) + ts.substring(11).replaceAll('-', ':');
      }
      parsedTime = DateTime.parse(ts).toLocal();
    } else {
      parsedTime = DateTime.now();
    }

    return HealthVitals(
      respiratoryRate: (json['respiratoryRate'] as num? ?? 0).toInt(),
      temperature: (json['temperature'] as num).toDouble(),
      timestamp: parsedTime,
    );
  }

  /// Returns a copy of this vitals object with the given fur offset applied.
  HealthVitals withFurOffset(double offset) => HealthVitals(
        respiratoryRate: respiratoryRate,
        temperature: temperature,
        timestamp: timestamp,
        furOffset: offset,
      );

  Map<String, dynamic> toJson() {
    return {
      'respiratoryRate': respiratoryRate,
      'temperature': temperature,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

enum VitalStatus { normal, caution, danger }