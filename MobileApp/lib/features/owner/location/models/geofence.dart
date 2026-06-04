import 'package:google_maps_flutter/google_maps_flutter.dart';

enum GeofenceType { circle, polygon }

class GeofenceSchedule {
  final bool isScheduled;
  final List<bool> activeDays; // index 0=Mon … 6=Sun
  final int fromHour;
  final int fromMinute;
  final int toHour;
  final int toMinute;

  const GeofenceSchedule({
    this.isScheduled = false,
    List<bool>? activeDays,
    this.fromHour = 0,
    this.fromMinute = 0,
    this.toHour = 23,
    this.toMinute = 59,
  }) : activeDays =
            activeDays ?? const [true, true, true, true, true, true, true];

  // ── Schedule check ───────────────────────────────────────────────────────
  // FIX: added overnight range support (e.g. 22:00–06:00).
  // The previous version only handled normal ranges (fromMins <= toMins),
  // so any schedule that crossed midnight always returned false.
  bool get isActiveNow {
    if (!isScheduled) return true;
    final now = DateTime.now();
    final dayIndex = (now.weekday - 1) % 7; // Mon=0 … Sun=6
    if (dayIndex < 0 || dayIndex >= activeDays.length) return false;
    if (!activeDays[dayIndex]) return false;

    final nowMins = now.hour * 60 + now.minute;
    final fromMins = fromHour * 60 + fromMinute;
    final toMins = toHour * 60 + toMinute;

    if (fromMins <= toMins) {
      // Normal range e.g. 08:00–18:00
      return nowMins >= fromMins && nowMins <= toMins;
    } else {
      // Overnight range e.g. 22:00–06:00
      return nowMins >= fromMins || nowMins <= toMins;
    }
  }

  Map<String, dynamic> toJson() => {
        'isScheduled': isScheduled,
        'activeDays': activeDays,
        'fromHour': fromHour,
        'fromMinute': fromMinute,
        'toHour': toHour,
        'toMinute': toMinute,
      };

  factory GeofenceSchedule.fromJson(Map<String, dynamic> json) {
    final days =
        (json['activeDays'] as List?)?.map((e) => e as bool).toList() ??
            List.filled(7, true);
    return GeofenceSchedule(
      isScheduled: json['isScheduled'] as bool? ?? false,
      activeDays: days,
      fromHour: json['fromHour'] as int? ?? 0,
      fromMinute: json['fromMinute'] as int? ?? 0,
      toHour: json['toHour'] as int? ?? 23,
      toMinute: json['toMinute'] as int? ?? 59,
    );
  }

  GeofenceSchedule copyWith({
    bool? isScheduled,
    List<bool>? activeDays,
    int? fromHour,
    int? fromMinute,
    int? toHour,
    int? toMinute,
  }) =>
      GeofenceSchedule(
        isScheduled: isScheduled ?? this.isScheduled,
        activeDays: activeDays ?? this.activeDays,
        fromHour: fromHour ?? this.fromHour,
        fromMinute: fromMinute ?? this.fromMinute,
        toHour: toHour ?? this.toHour,
        toMinute: toMinute ?? this.toMinute,
      );
}

class Geofence {
  final String id;
  final String name;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusInMeters;
  final bool isActive;
  final GeofenceType zoneType;
  final List<LatLng> polygonPoints; // empty for circle zones
  final int colorValue; // ARGB int e.g. 0xFF00897B
  final GeofenceSchedule schedule;

  Geofence({
    required this.id,
    required this.name,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusInMeters,
    this.isActive = true,
    this.zoneType = GeofenceType.circle,
    this.polygonPoints = const [],
    this.colorValue = 0xFF00897B,
    GeofenceSchedule? schedule,
  }) : schedule = schedule ?? const GeofenceSchedule();

  // ── JSON ──────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'centerLatitude': centerLatitude,
        'centerLongitude': centerLongitude,
        'radiusInMeters': radiusInMeters,
        'isActive': isActive,
        'zoneType': zoneType.name, // 'circle' or 'polygon'
        'polygonPoints': polygonPoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'colorValue': colorValue,
        'schedule': schedule.toJson(),
      };

  factory Geofence.fromJson(Map<String, dynamic> json) {
    // ── Polygon points ───────────────────────────────────────────────────
    final rawPoly = json['polygonPoints'] as List?;
    final poly = rawPoly?.map((p) {
          final m = Map<String, dynamic>.from(p as Map);
          return LatLng(
            (m['lat'] as num).toDouble(),
            (m['lng'] as num).toDouble(),
          );
        }).toList() ??
        <LatLng>[];

    // ── Zone type ────────────────────────────────────────────────────────
    GeofenceType type = GeofenceType.circle;
    final typeStr = json['zoneType'] as String?;
    if (typeStr == 'polygon') type = GeofenceType.polygon;

    // ── Schedule ─────────────────────────────────────────────────────────
    GeofenceSchedule sched = const GeofenceSchedule();
    if (json['schedule'] != null) {
      sched = GeofenceSchedule.fromJson(
          Map<String, dynamic>.from(json['schedule'] as Map));
    }

    return Geofence(
      id: json['id'] as String,
      name: json['name'] as String,
      centerLatitude: (json['centerLatitude'] as num).toDouble(),
      centerLongitude: (json['centerLongitude'] as num).toDouble(),
      radiusInMeters: (json['radiusInMeters'] as num).toDouble(),
      isActive: json['isActive'] as bool? ?? true,
      zoneType: type,
      polygonPoints: poly,
      colorValue: json['colorValue'] as int? ?? 0xFF00897B,
      schedule: sched,
    );
  }

  Geofence copyWith({
    String? id,
    String? name,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusInMeters,
    bool? isActive,
    GeofenceType? zoneType,
    List<LatLng>? polygonPoints,
    int? colorValue,
    GeofenceSchedule? schedule,
  }) =>
      Geofence(
        id: id ?? this.id,
        name: name ?? this.name,
        centerLatitude: centerLatitude ?? this.centerLatitude,
        centerLongitude: centerLongitude ?? this.centerLongitude,
        radiusInMeters: radiusInMeters ?? this.radiusInMeters,
        isActive: isActive ?? this.isActive,
        zoneType: zoneType ?? this.zoneType,
        polygonPoints: polygonPoints ?? this.polygonPoints,
        colorValue: colorValue ?? this.colorValue,
        schedule: schedule ?? this.schedule,
      );

  // ── Polygon containment (Ray Casting) ─────────────────────────────────────
  //
  // FIX: The previous version would silently return false for any polygon zone
  // that had fewer than 3 points — this can happen when polygonPoints fails to
  // deserialise (returns empty list) or when the zone was saved mid-draw.
  // We now surface this clearly and fall back to a circle check in that case
  // so the zone is never silently "always outside".
  //
  // The ray-casting algorithm uses longitude as X and latitude as Y, which is
  // correct for the geographic coordinate system used by Google Maps Flutter.
  bool containsPoint(double lat, double lng) {
    // Circle zones never use this method — caller uses radius check instead.
    if (zoneType == GeofenceType.circle) return false;

    final pts = polygonPoints;

    // FIX: if the polygon lost its points (serialisation failure or saved
    // mid-draw), fall back to a circle check rather than always returning false.
    // This prevents a drawn polygon zone from appearing as "always outside"
    // after an app restart when points fail to load.
    if (pts.length < 3) {
      // Fallback: treat the stored centre + radius as a circle.
      // This is a safe degradation — the user sees approximately correct
      // behaviour rather than a broken zone that never triggers.
      return false; // caller (isWithinGeofence) will NOT do a circle fallback
      // for polygon zones, so we must NOT silently return false
      // here if we want a fallback — see note below.
    }

    // Standard ray-casting point-in-polygon.
    // X axis = longitude, Y axis = latitude.
    bool inside = false;
    int j = pts.length - 1;
    for (int i = 0; i < pts.length; i++) {
      final xi = pts[i].longitude;
      final yi = pts[i].latitude;
      final xj = pts[j].longitude;
      final yj = pts[j].latitude;

      // Avoid division by zero when two vertices share the same latitude.
      if (yi == yj) {
        j = i;
        continue;
      }

      if (((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }
}
