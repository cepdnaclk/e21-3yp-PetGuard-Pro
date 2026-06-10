// lib/features/owner/activity/models/activity_data.dart
/*
class ActivityData {
  final String activityType;
  final double accelerometerX;
  final double accelerometerY;
  final double accelerometerZ;
  final double gyroscopeX;
  final double gyroscopeY;
  final double gyroscopeZ;
  final double magnitude;
  final bool impactDetected;
  final double impactSeverity;
  final DateTime timestamp;
  final int stepCount;
  final double activeMinutes;

  ActivityData({
    required this.activityType,
    required this.accelerometerX,
    required this.accelerometerY,
    required this.accelerometerZ,
    required this.gyroscopeX,
    required this.gyroscopeY,
    required this.gyroscopeZ,
    required this.magnitude,
    required this.impactDetected,
    required this.impactSeverity,
    required this.timestamp,
    required this.stepCount,
    required this.activeMinutes,
  });

  // ── Safe parsers ────────────────────────────────────────────────────────────
  // Firebase can return numbers as String, int, or double depending on how
  // the collar writes the data. These helpers handle all three cases safely.

  static double _toDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static bool _toBool(dynamic v, [bool fallback = false]) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is int) return v != 0;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  // ── fromMap ─────────────────────────────────────────────────────────────────
  factory ActivityData.fromMap(Map<dynamic, dynamic> map) {
    final accel = map['accelerometer'] as Map? ?? {};
    final gyro = map['gyroscope'] as Map? ?? {};

    // Timestamp: could be int (ms), String (ms), or missing
    DateTime ts;
    final rawTs = map['timestamp'];
    final tsMs = _toInt(rawTs, -1);
    ts = tsMs > 0 ? DateTime.fromMillisecondsSinceEpoch(tsMs) : DateTime.now();

    return ActivityData(
      activityType: map['activity_type']?.toString() ?? 'resting',
      accelerometerX: _toDouble(accel['x']),
      accelerometerY: _toDouble(accel['y']),
      accelerometerZ: _toDouble(accel['z']),
      gyroscopeX: _toDouble(gyro['x']),
      gyroscopeY: _toDouble(gyro['y']),
      gyroscopeZ: _toDouble(gyro['z']),
      magnitude: _toDouble(map['magnitude']),
      impactDetected: _toBool(map['impact_detected']),
      impactSeverity: _toDouble(map['impact_severity']),
      timestamp: ts,
      stepCount: _toInt(map['step_count']),
      activeMinutes: _toDouble(map['active_minutes']),
    );
  }

  // ── toMap ───────────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'activity_type': activityType,
      'accelerometer': {
        'x': accelerometerX,
        'y': accelerometerY,
        'z': accelerometerZ,
      },
      'gyroscope': {
        'x': gyroscopeX,
        'y': gyroscopeY,
        'z': gyroscopeZ,
      },
      'magnitude': magnitude,
      'impact_detected': impactDetected,
      'impact_severity': impactSeverity,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'step_count': stepCount,
      'active_minutes': activeMinutes,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ActivitySummary
// ─────────────────────────────────────────────────────────────────────────────

class ActivitySummary {
  final int totalSteps;
  final double totalActiveMinutes;
  final int impactCount;
  final Map<String, double> activityBreakdown;
  final DateTime date;

  ActivitySummary({
    required this.totalSteps,
    required this.totalActiveMinutes,
    required this.impactCount,
    required this.activityBreakdown,
    required this.date,
  });

  factory ActivitySummary.fromMap(Map<dynamic, dynamic> map) {
    // Safe breakdown parsing — values may also arrive as String
    final Map<String, double> breakdown = {};
    if (map['activity_breakdown'] != null) {
      (map['activity_breakdown'] as Map).forEach((k, v) {
        breakdown[k.toString()] = ActivityData._toDouble(v);
      });
    }

    final rawDate = map['date'];
    final dateMs = ActivityData._toInt(rawDate, -1);
    final date = dateMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(dateMs)
        : DateTime.now();

    return ActivitySummary(
      totalSteps: ActivityData._toInt(map['total_steps']),
      totalActiveMinutes: ActivityData._toDouble(map['total_active_minutes']),
      impactCount: ActivityData._toInt(map['impact_count']),
      activityBreakdown: breakdown,
      date: date,
    );
  }
}

*/


// lib/features/owner/activity/models/activity_data.dart

class ActivityData {
  final String activityType;
  final double accelerometerX;
  final double accelerometerY;
  final double accelerometerZ;
  final double gyroscopeX;
  final double gyroscopeY;
  final double gyroscopeZ;
  final double magnitude;
  final bool impactDetected;
  final double impactSeverity;
  final DateTime timestamp;
  final int stepCount;
  final double activeMinutes;

  ActivityData({
    required this.activityType,
    required this.accelerometerX,
    required this.accelerometerY,
    required this.accelerometerZ,
    required this.gyroscopeX,
    required this.gyroscopeY,
    required this.gyroscopeZ,
    required this.magnitude,
    required this.impactDetected,
    required this.impactSeverity,
    required this.timestamp,
    required this.stepCount,
    required this.activeMinutes,
  });

  // ── Safe parsers ────────────────────────────────────────────────────────────
  static double _toDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static bool _toBool(dynamic v, [bool fallback = false]) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is int) return v != 0;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  // ── fromMap ─────────────────────────────────────────────────────────────────
  factory ActivityData.fromMap(Map<dynamic, dynamic> map) {
    final accel = map['accelerometer'] as Map? ?? {};
    final gyro = map['gyroscope'] as Map? ?? {};

    DateTime ts;
    final rawTs = map['timestamp'];
    final tsMs = _toInt(rawTs, -1);
    ts = tsMs > 0 ? DateTime.fromMillisecondsSinceEpoch(tsMs) : DateTime.now();

    return ActivityData(
      activityType: map['activity_type']?.toString() ?? 'resting',
      accelerometerX: _toDouble(accel['x']),
      accelerometerY: _toDouble(accel['y']),
      accelerometerZ: _toDouble(accel['z']),
      gyroscopeX: _toDouble(gyro['x']),
      gyroscopeY: _toDouble(gyro['y']),
      gyroscopeZ: _toDouble(gyro['z']),
      magnitude: _toDouble(map['magnitude']),
      impactDetected: _toBool(map['impact_detected']),
      impactSeverity: _toDouble(map['impact_severity']),
      timestamp: ts,
      stepCount: _toInt(map['step_count']),
      activeMinutes: _toDouble(map['active_minutes']),
    );
  }

  // ── toMap ───────────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'activity_type': activityType,
      'accelerometer': {
        'x': accelerometerX,
        'y': accelerometerY,
        'z': accelerometerZ,
      },
      'gyroscope': {
        'x': gyroscopeX,
        'y': gyroscopeY,
        'z': gyroscopeZ,
      },
      'magnitude': magnitude,
      'impact_detected': impactDetected,
      'impact_severity': impactSeverity,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'step_count': stepCount,
      'active_minutes': activeMinutes,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ActivitySummary
// ─────────────────────────────────────────────────────────────────────────────

class ActivitySummary {
  final int totalSteps;
  final double totalActiveMinutes;
  final int impactCount;
  final Map<String, double> activityBreakdown;
  final DateTime date;
  final String peakIntensityTime; // ← ADDED

  ActivitySummary({
    required this.totalSteps,
    required this.totalActiveMinutes,
    required this.impactCount,
    required this.activityBreakdown,
    required this.date,
    this.peakIntensityTime = '--:--', // ← ADDED with default
  });

  factory ActivitySummary.fromMap(Map<dynamic, dynamic> map) {
    final Map<String, double> breakdown = {};
    if (map['activity_breakdown'] != null) {
      (map['activity_breakdown'] as Map).forEach((k, v) {
        breakdown[k.toString()] = ActivityData._toDouble(v);
      });
    }

    final rawDate = map['date'];
    final dateMs = ActivityData._toInt(rawDate, -1);
    final date = dateMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(dateMs)
        : DateTime.now();

    return ActivitySummary(
      totalSteps: ActivityData._toInt(map['total_steps']),
      totalActiveMinutes: ActivityData._toDouble(map['total_active_minutes']),
      impactCount: ActivityData._toInt(map['impact_count']),
      activityBreakdown: breakdown,
      date: date,
      peakIntensityTime: map['peak_intensity_time']?.toString() ?? '--:--', // ← ADDED
    );
  }
}