class Geofence {
  final String id;
  final String name;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusInMeters;
  final bool isActive;

  Geofence({
    required this.id,
    required this.name,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusInMeters,
    this.isActive = true,
  });

  // Convert to JSON (for Hive storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'radiusInMeters': radiusInMeters,
      'isActive': isActive,
    };
  }

  // Create from JSON (from Hive storage)
  factory Geofence.fromJson(Map<String, dynamic> json) {
    return Geofence(
      id: json['id'] as String,
      name: json['name'] as String,
      centerLatitude: (json['centerLatitude'] as num).toDouble(),
      centerLongitude: (json['centerLongitude'] as num).toDouble(),
      radiusInMeters: (json['radiusInMeters'] as num).toDouble(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  // Create a copy with modified fields
  Geofence copyWith({
    String? id,
    String? name,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusInMeters,
    bool? isActive,
  }) {
    return Geofence(
      id: id ?? this.id,
      name: name ?? this.name,
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      radiusInMeters: radiusInMeters ?? this.radiusInMeters,
      isActive: isActive ?? this.isActive,
    );
  }
}
