class PetLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;
  final double? heading;

  PetLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
    this.heading,
  });

  factory PetLocation.fromPosition(dynamic position) {
    return PetLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp ?? DateTime.now(),
      heading: position.heading,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'heading': heading,
    };
  }

  factory PetLocation.fromJson(Map<String, dynamic> json) {
    // Handle all timestamp formats:
    // 1. int  — Firebase server timestamp (Unix ms) ✅
    // 2. String — ISO string from ESP32 firmware
    DateTime parsedTime;
    final rawTs = json['timestamp'];

    if (rawTs is int) {
      // Firebase server timestamp — most accurate ✅
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTs).toLocal();
    } else if (rawTs is String) {
      try {
        parsedTime = DateTime.parse(rawTs).toLocal();
      } catch (_) {
        parsedTime = DateTime.now();
      }
    } else {
      parsedTime = DateTime.now();
    }

    return PetLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: json['accuracy'] != null
          ? (json['accuracy'] as num).toDouble()
          : null,
      timestamp: parsedTime,
      heading:
          json['heading'] != null ? (json['heading'] as num).toDouble() : null,
    );
  }

  @override
  String toString() {
    return 'PetLocation(lat: $latitude, lng: $longitude, time: $timestamp)';
  }
}
