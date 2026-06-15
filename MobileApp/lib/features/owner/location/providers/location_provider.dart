// lib/features/owner/location/providers/location_provider.dart

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
import 'alerts_provider.dart';

// ─────────────────────────────────────────────────────────────
// Provider for LocationService instance
// ─────────────────────────────────────────────────────────────
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// ─────────────────────────────────────────────────────────────
// Provider for current location (one-time)
// ─────────────────────────────────────────────────────────────
final currentLocationProvider = FutureProvider<PetLocation?>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  final position = await locationService.getCurrentLocation();
  if (position != null) {
    return PetLocation.fromPosition(position);
  }
  return null;
});

// ─────────────────────────────────────────────────────────────
// Provider for location permission status
// ─────────────────────────────────────────────────────────────
final locationPermissionProvider = FutureProvider<bool>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  return await locationService.requestLocationPermission();
});

// ─────────────────────────────────────────────────────────────
// CloudService provider
// ─────────────────────────────────────────────────────────────
final cloudServiceProvider = Provider<CloudService>((ref) {
  return CloudService();
});

// ─────────────────────────────────────────────────────────────
// FIX: selectedPetId for location — resolves once and drives
// all location providers. When the account changes and this
// provider is invalidated, ALL downstream providers
// (locationStreamProvider, history, recent) automatically
// restart with the correct new pet ID.
// ─────────────────────────────────────────────────────────────
final locationPetIdProvider = FutureProvider<String?>((ref) async {
  final cloudService = ref.watch(cloudServiceProvider);
  try {
    return await cloudService.getPetId();
  } catch (_) {
    return null;
  }
});

// ─────────────────────────────────────────────────────────────
// FIX: locationStreamProvider now WAITS for the resolved petId
// before starting the Firebase stream.
// Previously it called getLocationStream() on a singleton that
// resolved the petId once and cached it — so switching accounts
// kept streaming the old pet's data until multiple refreshes
// forced a provider rebuild.
// ─────────────────────────────────────────────────────────────
final locationStreamProvider = StreamProvider<PetLocation>((ref) async* {
  final petId = await ref.watch(locationPetIdProvider.future);
  if (petId == null) return;
  final cloudService = ref.watch(cloudServiceProvider);
  yield* cloudService.getLocationStreamForPet(petId);
});

// ─────────────────────────────────────────────────────────────
// Geofence state
// ─────────────────────────────────────────────────────────────
class GeofenceState {
  final List<Geofence> geofences;
  GeofenceState({this.geofences = const []});
  GeofenceState copyWith({List<Geofence>? geofences}) {
    return GeofenceState(geofences: geofences ?? this.geofences);
  }
}

class GeofenceNotifier extends Notifier<GeofenceState> {
  late Box _geofenceBox;

  @override
  GeofenceState build() {
    _geofenceBox = Hive.box('geofences');
    final savedGeofences = _loadGeofences();
    return GeofenceState(geofences: savedGeofences);
  }

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

  void _saveGeofence(Geofence geofence) {
    _geofenceBox.put(geofence.id, geofence.toJson());
    debugPrint('Saved geofence: ${geofence.name} (${geofence.id})');
  }

  void _deleteGeofence(String id) {
    _geofenceBox.delete(id);
  }

  void addGeofence(Geofence geofence) {
    _saveGeofence(geofence);
    state = state.copyWith(geofences: [...state.geofences, geofence]);
  }

  void removeGeofence(String id) {
    _deleteGeofence(id);
    state = state.copyWith(
      geofences: state.geofences.where((fence) => fence.id != id).toList(),
    );
  }

  void updateGeofence(Geofence updatedGeofence) {
    _saveGeofence(updatedGeofence);
    state = state.copyWith(
      geofences: [
        for (final fence in state.geofences)
          if (fence.id == updatedGeofence.id) updatedGeofence else fence,
      ],
    );
  }

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
        geofence: fence,
      );
      if (!isInside) {
        breachedFences.add(fence);
      }
    }
    return breachedFences;
  }

  List<Geofence> getActiveGeofences() {
    return state.geofences.where((fence) => fence.isActive).toList();
  }

  void clearAll() {
    _geofenceBox.clear();
    state = state.copyWith(geofences: []);
  }
}

final geofenceProvider = NotifierProvider<GeofenceNotifier, GeofenceState>(() {
  return GeofenceNotifier();
});

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

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final geofenceMonitorProvider = Provider<void>((ref) {
  final locationAsync = ref.watch(locationStreamProvider);
  final notificationService = ref.read(notificationServiceProvider);

  locationAsync.whenData((location) {
    final notifier = ref.read(geofenceProvider.notifier);
    final breachedFences = notifier.checkGeofenceBreaches(location);

    for (final fence in breachedFences) {
      notificationService.showGeofenceBreachAlert(
        geofenceName: fence.name,
        petName: 'Your Pet',
      );

      ref.read(alertsProvider.notifier).add(
            AppAlert(
              title: '⚠️ Zone breach: ${fence.name}',
              body: 'Your pet has left the safe zone.',
              timestamp: DateTime.now(),
            ),
          );
    }
  });
});

final locationHistoryServiceProvider = Provider<LocationHistoryService>((ref) {
  return LocationHistoryService();
});

final locationHistorySaverProvider = Provider<void>((ref) {
  final locationAsync = ref.watch(locationStreamProvider);
  final historyService = ref.read(locationHistoryServiceProvider);
  final cloudService = ref.read(cloudServiceProvider);

  locationAsync.whenData((location) async {
    await historyService.saveLocation(location);
    try {
      final entry = LocationHistoryEntry.fromPetLocation(location);
      await cloudService.saveHistoryEntry(entry);
    } catch (e) {
      debugPrint('Failed to save history entry to Firebase: $e');
    }
  });
});

// ─────────────────────────────────────────────────────────────
// FIX: locationHistoryProvider now also waits for petId before
// fetching — previously it called cloudService.getLocationHistory()
// which internally called _getPetId() each loop iteration, but
// the singleton cached stale data on first call.
// ─────────────────────────────────────────────────────────────
final locationHistoryProvider =
    StreamProvider<List<LocationHistoryEntry>>((ref) async* {
  final historyService = ref.read(locationHistoryServiceProvider);
  final cloudService = ref.read(cloudServiceProvider);

  // Wait for the correct petId before starting the history loop
  final petId = await ref.watch(locationPetIdProvider.future);
  if (petId == null) {
    yield [];
    return;
  }

  await historyService.initialize();

  while (true) {
    try {
      final rawHistory = await cloudService.getLocationHistoryForPet(petId);
      if (rawHistory.isNotEmpty) {
        final entries = rawHistory
            .map((json) => LocationHistoryEntry.tryFromJson(json))
            .whereType<LocationHistoryEntry>()
            .toList();
        debugPrint('History provider: ${entries.length} entries from Firebase');
        yield entries;
        await Future.delayed(const Duration(seconds: 10));
        continue;
      }
    } catch (e) {
      debugPrint('Firebase history failed, falling back to Hive: $e');
    }

    final entries = await historyService.getAllHistory();
    debugPrint('History provider: ${entries.length} entries from Hive');
    yield entries;

    await Future.delayed(const Duration(seconds: 10));
  }
});

// ─────────────────────────────────────────────────────────────
// FIX: same fix applied to recentLocationsProvider
// ─────────────────────────────────────────────────────────────
final recentLocationsProvider =
    StreamProvider<List<LocationHistoryEntry>>((ref) async* {
  final historyService = ref.read(locationHistoryServiceProvider);
  final cloudService = ref.read(cloudServiceProvider);

  // Wait for the correct petId before starting the loop
  final petId = await ref.watch(locationPetIdProvider.future);
  if (petId == null) {
    yield [];
    return;
  }

  await historyService.initialize();

  while (true) {
    try {
      final rawHistory = await cloudService.getLocationHistoryForPet(petId);
      if (rawHistory.isNotEmpty) {
        final entries = rawHistory
            .take(10)
            .map((json) => LocationHistoryEntry.tryFromJson(json))
            .whereType<LocationHistoryEntry>()
            .toList();
        yield entries;
        await Future.delayed(const Duration(seconds: 10));
        continue;
      }
    } catch (e) {
      debugPrint('Firebase history failed, falling back to Hive: $e');
    }

    final entries = await historyService.getLastNLocations(10);
    yield entries;
    await Future.delayed(const Duration(seconds: 10));
  }
});
