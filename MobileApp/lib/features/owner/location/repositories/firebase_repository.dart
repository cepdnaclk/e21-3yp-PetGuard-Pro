import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'cloud_repository.dart';
import '../models/pet_location.dart';
import '../models/geofence.dart';

class FirebaseRepository implements CloudRepository {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    if (!kIsWeb) {
      try {
        _database.setPersistenceEnabled(true);
        _database.setPersistenceCacheSizeBytes(10000000);
      } catch (e) {
        debugPrint('Persistence not available: $e');
      }
    }

    _initialized = true;
    debugPrint('Firebase repository initialized');
  }

  @override
  Stream<PetLocation> getLocationStream(String petId) {
    return _database.ref('pets/$petId/current_location').onValue.map((event) {
      if (event.snapshot.value == null) {
        throw Exception('No location data');
      }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return PetLocation.fromJson(data);
    });
  }

  @override
  Future<void> uploadLocation(String petId, PetLocation location) async {
    try {
      await _database
          .ref('pets/$petId/current_location')
          .set(location.toJson());
      debugPrint('Uploaded location to Firebase');
    } catch (e) {
      debugPrint('Failed to upload location: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveGeofence(String petId, Geofence geofence) async {
    try {
      await _database
          .ref('pets/$petId/geofences/${geofence.id}')
          .set(geofence.toJson());
      debugPrint('Saved geofence to Firebase: ${geofence.name}');
    } catch (e) {
      debugPrint('Failed to save geofence: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteGeofence(String petId, String geofenceId) async {
    try {
      await _database.ref('pets/$petId/geofences/$geofenceId').remove();
      debugPrint('Deleted geofence from Firebase: $geofenceId');
    } catch (e) {
      debugPrint('Failed to delete geofence: $e');
      rethrow;
    }
  }

  @override
  Future<List<Geofence>> getGeofences(String petId) async {
    try {
      final snapshot = await _database.ref('pets/$petId/geofences').get();
      if (!snapshot.exists) return [];

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final geofences = <Geofence>[];
      for (var entry in data.entries) {
        try {
          final geofenceData = Map<String, dynamic>.from(entry.value as Map);
          geofences.add(Geofence.fromJson(geofenceData));
        } catch (e) {
          debugPrint('Failed to parse geofence: $e');
        }
      }
      return geofences;
    } catch (e) {
      debugPrint('Failed to get geofences: $e');
      return [];
    }
  }

  @override
  Stream<List<Geofence>> getGeofencesStream(String petId) {
    return _database.ref('pets/$petId/geofences').onValue.map((event) {
      if (event.snapshot.value == null) return <Geofence>[];

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final geofences = <Geofence>[];
      for (var entry in data.entries) {
        try {
          final geofenceData = Map<String, dynamic>.from(entry.value as Map);
          geofences.add(Geofence.fromJson(geofenceData));
        } catch (e) {
          debugPrint('Failed to parse geofence: $e');
        }
      }
      return geofences;
    });
  }

  @override
  Future<void> uploadLocationHistory(String petId, List history) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      for (var entry in history.take(100)) {
        await _database
            .ref('pets/$petId/location_history/$timestamp')
            .set(entry.toJson());
      }
      debugPrint('Uploaded location history to Firebase');
    } catch (e) {
      debugPrint('Failed to upload history: $e');
    }
  }

  @override
  Future<void> logEvent(
      String petId, String eventType, Map<String, dynamic> data) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _database.ref('pets/$petId/events/$timestamp').set({
        'type': eventType,
        'timestamp': timestamp,
        'data': data,
      });
      debugPrint('Logged event to Firebase: $eventType');
    } catch (e) {
      debugPrint('Failed to log event: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getLocationHistory(String petId) async {
    try {
      final snapshot = await _database
          .ref('pets/$petId/location_history')
          .orderByKey()
          .get();

      if (!snapshot.exists) return [];

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final List<Map<String, dynamic>> history = [];
      for (var entry in data.entries) {
        try {
          history.add(Map<String, dynamic>.from(entry.value as Map));
        } catch (e) {
          debugPrint('Failed to parse history entry: $e');
        }
      }

      history.sort((a, b) {
        final aTime = _parseTimestamp(a['timestamp']);
        final bTime = _parseTimestamp(b['timestamp']);
        return bTime.compareTo(aTime);
      });

      debugPrint('Fetched ${history.length} history entries from Firebase');
      return history;
    } catch (e) {
      debugPrint('Failed to get location history: $e');
      return [];
    }
  }

  @override
  Future<void> saveHistoryEntry(
      String petId, Map<String, dynamic> entry) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _database.ref('pets/$petId/location_history/$timestamp').set(entry);
      debugPrint('Saved history entry to Firebase');
    } catch (e) {
      debugPrint('Failed to save history entry: $e');
    }
  }

  /// Safely parse a timestamp string that may contain +05:30 or Z suffix.
  /// DateTime.parse() fails on ±HH:MM offsets on some platforms, so we
  /// normalise the string by replacing the offset with Z before parsing.
  static DateTime _parseTimestamp(dynamic ts) {
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    if (ts is String) {
      try {
        // Replace +HH:MM or -HH:MM offset with Z so DateTime.parse works
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

  @override
  Stream<List<Map<String, dynamic>>> getLocationHistoryStream(String petId) {
    return _database
        .ref('pets/$petId/location_history')
        .orderByKey()
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return <Map<String, dynamic>>[];

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final List<Map<String, dynamic>> history = [];
      for (var entry in data.entries) {
        try {
          history.add(Map<String, dynamic>.from(entry.value as Map));
        } catch (e) {
          debugPrint('Failed to parse history entry in stream: $e');
        }
      }

      history.sort((a, b) {
        final aTime = _parseTimestamp(a['timestamp']);
        final bTime = _parseTimestamp(b['timestamp']);
        return bTime.compareTo(aTime);
      });

      debugPrint('History stream pushed ${history.length} entries');
      return history;
    });
  }

  /// ── NEW: Write a command payload to Firebase for the ESP32 to poll ────────
  /// Firebase path: pets/{petId}/commands/{commandName}
  /// The ESP32 firmware reads this node every loop cycle and acts accordingly.
  @override
  Future<void> sendCommand(
      String petId, String commandName, Map<String, dynamic> payload) async {
    try {
      await _database.ref('pets/$petId/commands/$commandName').set(payload);
      debugPrint('Command sent to Firebase: $commandName = $payload');
    } catch (e) {
      debugPrint('Failed to send command $commandName: $e');
      rethrow;
    }
  }
}
