import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/pet_location.dart';
import '../models/geofence.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/location_history_service.dart';
import '../services/cloud_service.dart';
import '../models/location_history_entry.dart';

// Provider for LocationService instance
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// Provider for current location (one-time)
final currentLocationProvider = FutureProvider<PetLocation?>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  final position = await locationService.getCurrentLocation();

  if (position != null) {
    return PetLocation.fromPosition(position);
  }
  return null;
});

// Provider for location permission status
final locationPermissionProvider = FutureProvider<bool>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  return await locationService.requestLocationPermission();
});

// Provider for continuous location tracking stream
// FIREBASE VERSION - Gets data from cloud instead of local GPS
final locationStreamProvider = StreamProvider<PetLocation>((ref) {
  final cloudService = ref.read(cloudServiceProvider);

  // Get location from Firebase instead of local GPS
  return cloudService.getLocationStream();
});

// Add cloud service provider
final cloudServiceProvider = Provider<CloudService>((ref) {
  return CloudService();
});

// Simple state class for geofences
class GeofenceState {
  final List<Geofence> geofences;

  GeofenceState({this.geofences = const []});

  GeofenceState copyWith({List<Geofence>? geofences}) {
    return GeofenceState(geofences: geofences ?? this.geofences);
  }
}

// Geofence Notifier using StateNotifier alternative
// Geofence Notifier with Local Storage
class GeofenceNotifier extends Notifier<GeofenceState> {
  late Box _geofenceBox;

  @override
  GeofenceState build() {
    _geofenceBox = Hive.box('geofences');

    // Load saved geofences on startup
    final savedGeofences = _loadGeofences();

    return GeofenceState(geofences: savedGeofences);
  }

  // Load geofences from Hive
  List<Geofence> _loadGeofences() {
    final List<Geofence> geofences = [];

    debugPrint('Loading geofences from Hive...');
    debugPrint('Total keys in box: ${_geofenceBox.keys.length}');

    for (var key in _geofenceBox.keys) {
      try {
        final json = _geofenceBox.get(key) as Map<dynamic, dynamic>;
        final geofence = Geofence.fromJson(Map<String, dynamic>.from(json));
        geofences.add(geofence);
        debugPrint('Loaded geofence: ${geofence.name} (${geofence.id})');
      } catch (e) {
        debugPrint('Error loading geofence $key: $e');
      }
    }

    debugPrint('Total geofences loaded: ${geofences.length}');
    return geofences;
  }

  // Save geofence to Hive
  void _saveGeofence(Geofence geofence) {
    _geofenceBox.put(geofence.id, geofence.toJson());
    debugPrint('Saved geofence: ${geofence.name} (${geofence.id})');
  }

  // Delete geofence from Hive
  void _deleteGeofence(String id) {
    _geofenceBox.delete(id);
  }

  // Add a new geofence
  void addGeofence(Geofence geofence) {
    // Save to local storage
    _saveGeofence(geofence);

    // Update state
    state = state.copyWith(geofences: [...state.geofences, geofence]);
  }

  // Remove a geofence by ID
  void removeGeofence(String id) {
    // Delete from local storage
    _deleteGeofence(id);

    // Update state
    state = state.copyWith(
      geofences: state.geofences.where((fence) => fence.id != id).toList(),
    );
  }

  // Update a geofence
  void updateGeofence(Geofence updatedGeofence) {
    // Save to local storage
    _saveGeofence(updatedGeofence);

    // Update state
    state = state.copyWith(
      geofences: [
        for (final fence in state.geofences)
          if (fence.id == updatedGeofence.id) updatedGeofence else fence,
      ],
    );
  }

  // Toggle geofence active status
  void toggleGeofence(String id) {
    final geofences = state.geofences;
    final index = geofences.indexWhere((fence) => fence.id == id);

    if (index != -1) {
      final updatedGeofence = geofences[index].copyWith(
        isActive: !geofences[index].isActive,
      );
      updateGeofence(updatedGeofence);
    }
  }

  // Check if current location is outside any active geofence
  List<Geofence> checkGeofenceBreaches(PetLocation currentLocation) {
    final locationService = ref.read(locationServiceProvider);
    List<Geofence> breachedFences = [];

    for (final fence in state.geofences) {
      if (!fence.isActive) continue;

      bool isInside = locationService.isWithinGeofence(
        currentLat: currentLocation.latitude,
        currentLng: currentLocation.longitude,
        centerLat: fence.centerLatitude,
        centerLng: fence.centerLongitude,
        radiusInMeters: fence.radiusInMeters,
      );

      if (!isInside) {
        breachedFences.add(fence);
      }
    }

    return breachedFences;
  }

  // Get all active geofences
  List<Geofence> getActiveGeofences() {
    return state.geofences.where((fence) => fence.isActive).toList();
  }

  // Clear all geofences
  void clearAll() {
    // Clear from local storage
    _geofenceBox.clear();

    // Update state
    state = state.copyWith(geofences: []);
  }
}

// Provider for geofence management
final geofenceProvider = NotifierProvider<GeofenceNotifier, GeofenceState>(() {
  return GeofenceNotifier();
});

// Provider to check for geofence breaches
final geofenceBreachProvider = Provider<List<Geofence>>((ref) {
  final currentLocationAsync = ref.watch(locationStreamProvider);

  return currentLocationAsync.when(
    data: (location) {
      final notifier = ref.read(geofenceProvider.notifier);
      return notifier.checkGeofenceBreaches(location);
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Provider to monitor geofence breaches and send notifications
final geofenceMonitorProvider = Provider<void>((ref) {
  final locationAsync = ref.watch(locationStreamProvider);
  final notificationService = ref.read(notificationServiceProvider);

  locationAsync.whenData((location) {
    final notifier = ref.read(geofenceProvider.notifier);
    final breachedFences = notifier.checkGeofenceBreaches(location);

    // Send notification for each breached geofence
    for (final fence in breachedFences) {
      notificationService.showGeofenceBreachAlert(
        geofenceName: fence.name,
        petName: 'Your Pet', // You can customize this later
      );
    }
  });
});

// Provider for location history service
final locationHistoryServiceProvider = Provider<LocationHistoryService>((ref) {
  return LocationHistoryService();
});

// Provider to automatically save location history to Hive + Firebase
final locationHistorySaverProvider = Provider<void>((ref) {
  final locationAsync = ref.watch(locationStreamProvider);
  final historyService = ref.read(locationHistoryServiceProvider);
  final cloudService = ref.read(cloudServiceProvider);

  locationAsync.whenData((location) async {
    // Save to Hive (local cache)
    await historyService.saveLocation(location);

    // Save to Firebase (primary source)
    try {
      final entry = LocationHistoryEntry.fromPetLocation(location);
      await cloudService.saveHistoryEntry(entry);
    } catch (e) {
      debugPrint('Failed to save history entry to Firebase: $e');
    }
  });
});

// Full history — Firebase primary, Hive fallback
final locationHistoryProvider =
    FutureProvider<List<LocationHistoryEntry>>((ref) async {
  ref.watch(locationStreamProvider);

  try {
    final cloudService = ref.read(cloudServiceProvider);
    final rawHistory = await cloudService.getLocationHistory();

    if (rawHistory.isNotEmpty) {
      return rawHistory
          .map((json) => LocationHistoryEntry.fromJson(json))
          .toList();
    }
  } catch (e) {
    debugPrint('Firebase history failed, falling back to Hive: $e');
  }

  final historyService = ref.read(locationHistoryServiceProvider);
  return await historyService.getAllHistory();
});

// Recent 10 locations — Firebase primary, Hive fallback
final recentLocationsProvider =
    FutureProvider<List<LocationHistoryEntry>>((ref) async {
  ref.watch(locationStreamProvider);

  try {
    final cloudService = ref.read(cloudServiceProvider);
    final rawHistory = await cloudService.getLocationHistory();

    if (rawHistory.isNotEmpty) {
      return rawHistory
          .take(10)
          .map((json) => LocationHistoryEntry.fromJson(json))
          .toList();
    }
  } catch (e) {
    debugPrint('Firebase history failed, falling back to Hive: $e');
  }

  final historyService = ref.read(locationHistoryServiceProvider);
  return await historyService.getLastNLocations(10);
});
