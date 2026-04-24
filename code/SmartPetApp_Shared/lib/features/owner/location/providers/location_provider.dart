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

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final currentLocationProvider = FutureProvider<PetLocation?>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  final position = await locationService.getCurrentLocation();
  if (position != null) {
    return PetLocation.fromPosition(position);
  }
  return null;
});

final locationPermissionProvider = FutureProvider<bool>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  return await locationService.requestLocationPermission();
});

final locationStreamProvider = StreamProvider<PetLocation>((ref) {
  final cloudService = ref.read(cloudServiceProvider);
  return cloudService.getLocationStream();
});

final cloudServiceProvider = Provider<CloudService>((ref) {
  return CloudService();
});

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

final locationHistoryProvider =
    StreamProvider<List<LocationHistoryEntry>>((ref) {
  final cloudService = ref.read(cloudServiceProvider);

  return cloudService.getLocationHistoryStream().map((rawHistory) {
    if (rawHistory.isNotEmpty) {
      return rawHistory
          .map((json) => LocationHistoryEntry.fromJson(json))
          .toList();
    }
    return <LocationHistoryEntry>[];
  });
});

final recentLocationsProvider =
    StreamProvider<List<LocationHistoryEntry>>((ref) {
  final cloudService = ref.read(cloudServiceProvider);

  return cloudService.getLocationHistoryStream().map((rawHistory) {
    return rawHistory
        .take(10)
        .map((json) => LocationHistoryEntry.fromJson(json))
        .toList();
  });
});
