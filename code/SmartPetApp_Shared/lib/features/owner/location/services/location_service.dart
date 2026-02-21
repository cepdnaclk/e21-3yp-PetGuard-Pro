import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  // Singleton pattern - ensures only one instance exists
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Stream for real-time location updates
  Stream<Position>? _positionStream;

  // Location settings
  final LocationSettings _locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // Update every 10 meters
  );

  /// Check if location services are enabled on the device
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permissions from user
  Future<bool> requestLocationPermission() async {
    // Check current permission status
    PermissionStatus status = await Permission.location.status;

    if (status.isGranted) {
      return true;
    }

    // Request permission if not granted
    if (status.isDenied) {
      status = await Permission.location.request();
    }

    // For Android 10+ background location
    if (status.isGranted) {
      PermissionStatus backgroundStatus =
          await Permission.locationAlways.status;
      if (backgroundStatus.isDenied) {
        await Permission.locationAlways.request();
      }
    }

    return status.isGranted;
  }

  /// Get current one-time location
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check permissions
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw Exception('Location permission denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      // Log error (in production, use proper logging)
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Start continuous location tracking
  Stream<Position> getLocationStream() {
    _positionStream ??= Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    );

    return _positionStream!;
  }

  /// Calculate distance between two points in meters
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Check if a point is within a circular geofence
  bool isWithinGeofence({
    required double currentLat,
    required double currentLng,
    required double centerLat,
    required double centerLng,
    required double radiusInMeters,
  }) {
    double distance = calculateDistance(
      currentLat,
      currentLng,
      centerLat,
      centerLng,
    );

    return distance <= radiusInMeters;
  }
}
