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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
    };
  }

  factory LocationHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LocationHistoryEntry(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      accuracy: json['accuracy'] != null
          ? (json['accuracy'] as num).toDouble()
          : null,
    );
  }

  @override
  String toString() {
    return 'LocationHistoryEntry(lat: $latitude, lng: $longitude, time: $timestamp)';
  }
}
