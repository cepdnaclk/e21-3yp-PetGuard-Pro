import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/location_history_entry.dart';
import '../models/pet_location.dart';
import 'dart:math' as math;

class LocationHistoryService {
  // Singleton pattern
  static final LocationHistoryService _instance =
      LocationHistoryService._internal();
  factory LocationHistoryService() => _instance;
  LocationHistoryService._internal();

  late Box _historyBox;
  bool _initialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;

    _historyBox = Hive.box('location_history');
    _initialized = true;

    debugPrint('Location history service initialized');
  }

  /// Save a location to history
  Future<void> saveLocation(PetLocation location) async {
    if (!_initialized) await initialize();

    final entry = LocationHistoryEntry.fromPetLocation(location);

    await _historyBox.put(entry.id, entry.toJson());

    debugPrint('Saved location history: ${entry.id}');

    // Clean old entries (keep last 1000)
    await _cleanOldEntries();
  }

  /// Get all location history
  Future<List<LocationHistoryEntry>> getAllHistory() async {
    if (!_initialized) await initialize();

    final List<LocationHistoryEntry> history = [];

    for (var key in _historyBox.keys) {
      try {
        final json = _historyBox.get(key) as Map<dynamic, dynamic>;
        final entry = LocationHistoryEntry.fromJson(
          Map<String, dynamic>.from(json),
        );
        history.add(entry);
      } catch (e) {
        debugPrint('Error loading history entry $key: $e');
      }
    }

    // Sort by timestamp (newest first)
    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return history;
  }

  /// Get history for a specific date
  Future<List<LocationHistoryEntry>> getHistoryForDate(DateTime date) async {
    final allHistory = await getAllHistory();

    return allHistory.where((entry) {
      return entry.timestamp.year == date.year &&
          entry.timestamp.month == date.month &&
          entry.timestamp.day == date.day;
    }).toList();
  }

  /// Get history for date range
  Future<List<LocationHistoryEntry>> getHistoryForRange(
    DateTime start,
    DateTime end,
  ) async {
    final allHistory = await getAllHistory();

    return allHistory.where((entry) {
      return entry.timestamp.isAfter(start) && entry.timestamp.isBefore(end);
    }).toList();
  }

  /// Get last N locations
  Future<List<LocationHistoryEntry>> getLastNLocations(int count) async {
    final allHistory = await getAllHistory();

    if (allHistory.length <= count) {
      return allHistory;
    }

    return allHistory.sublist(0, count);
  }

  /// Calculate total distance traveled (in meters)
  double calculateTotalDistance(List<LocationHistoryEntry> entries) {
    if (entries.length < 2) return 0.0;

    double totalDistance = 0.0;

    for (int i = 0; i < entries.length - 1; i++) {
      final entry1 = entries[i];
      final entry2 = entries[i + 1];

      // Use Haversine formula for distance
      final distance = _calculateDistance(
        entry1.latitude,
        entry1.longitude,
        entry2.latitude,
        entry2.longitude,
      );

      totalDistance += distance;
    }

    return totalDistance;
  }

  /// Calculate distance between two points (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// Clean old entries (keep last 1000)
  Future<void> _cleanOldEntries() async {
    if (_historyBox.length <= 1000) return;

    final allHistory = await getAllHistory();

    // Keep last 1000, delete rest
    final toDelete = allHistory.skip(1000);

    for (var entry in toDelete) {
      await _historyBox.delete(entry.id);
    }

    debugPrint('Cleaned ${toDelete.length} old location entries');
  }

  /// Clear all history
  Future<void> clearAllHistory() async {
    if (!_initialized) await initialize();

    await _historyBox.clear();
    debugPrint('Cleared all location history');
  }

  /// Get total count
  int getCount() {
    return _historyBox.length;
  }
}
