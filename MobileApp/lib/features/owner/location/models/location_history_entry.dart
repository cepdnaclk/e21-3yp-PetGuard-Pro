class LocationHistoryEntry {
  final String id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;

  LocationHistoryEntry({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  });

  factory LocationHistoryEntry.fromPetLocation(dynamic petLocation) {
    return LocationHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      latitude: petLocation.latitude,
      longitude: petLocation.longitude,
      timestamp: petLocation.timestamp,
      accuracy: petLocation.accuracy,
    );
  }

  /// Safely parse timestamps regardless of format:
  ///   "2026-04-30T14:23:00.000+05:30"  ← ESP32 firmware format
  ///   "2026-04-30T08:53:00.000Z"        ← UTC format
  ///   1746000000000                     ← Unix ms integer
  static DateTime _parseTimestamp(dynamic ts) {
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    if (ts is String) {
      try {
        // Replace ±HH:MM timezone offset with Z so DateTime.parse works
        final normalised = ts.replaceAllMapped(
          RegExp(r'[+-]\d{2}:\d{2}$'),
          (_) => 'Z',
        );
        return DateTime.parse(normalised);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  factory LocationHistoryEntry.fromJson(Map<String, dynamic> json) {
    final parsedTime = _parseTimestamp(json['timestamp']);

    return LocationHistoryEntry(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: parsedTime,
      accuracy: json['accuracy'] != null
          ? (json['accuracy'] as num).toDouble()
          : null,
    );
  }

  /// Returns null if the entry is missing required fields (lat/lng/timestamp).
  /// Use this in stream mappings so one bad entry doesn't crash the whole list.
  static LocationHistoryEntry? tryFromJson(Map<String, dynamic> json) {
    try {
      final lat = json['latitude'];
      final lng = json['longitude'];
      // Skip entries with null or zero coordinates
      if (lat == null || lng == null) return null;
      final latD = (lat as num).toDouble();
      final lngD = (lng as num).toDouble();
      if (latD == 0.0 && lngD == 0.0) return null;

      return LocationHistoryEntry(
        id: json['id'] as String? ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        latitude: latD,
        longitude: lngD,
        timestamp: _parseTimestamp(json['timestamp']),
        accuracy: json['accuracy'] != null
            ? (json['accuracy'] as num).toDouble()
            : null,
      );
    } catch (e) {
      return null; // silently skip malformed entries
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
    };
  }

  @override
  String toString() {
    return 'LocationHistoryEntry(lat: $latitude, lng: $longitude, time: $timestamp)';
  }
}
