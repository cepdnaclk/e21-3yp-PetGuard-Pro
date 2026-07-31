import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/geofence.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Stream<Position>? _positionStream;

  final LocationSettings _locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  Future<bool> isLocationServiceEnabled() async =>
      Geolocator.isLocationServiceEnabled();

  Future<bool> requestLocationPermission() async {
    PermissionStatus status = await Permission.location.status;
    if (status.isGranted) return true;
    if (status.isDenied) status = await Permission.location.request();
    if (status.isGranted) {
      final bg = await Permission.locationAlways.status;
      if (bg.isDenied) await Permission.locationAlways.request();
    }
    return status.isGranted;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      if (!await isLocationServiceEnabled()) {
        throw Exception('Location services are disabled');
      }
      if (!await requestLocationPermission()) {
        throw Exception('Location permission denied');
      }
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  Stream<Position> getLocationStream() {
    _positionStream ??=
        Geolocator.getPositionStream(locationSettings: _locationSettings);
    return _positionStream!;
  }

  double calculateDistance(
          double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

  /// Works for both circle and polygon geofences.
  bool isWithinGeofence({
    required double currentLat,
    required double currentLng,
    required double centerLat,
    required double centerLng,
    required double radiusInMeters,
    Geofence? geofence,
  }) {
    // Polygon check
    if (geofence != null && geofence.zoneType == GeofenceType.polygon) {
      return geofence.containsPoint(currentLat, currentLng);
    }
    // Circle check
    return calculateDistance(currentLat, currentLng, centerLat, centerLng) <=
        radiusInMeters;
  }
}
