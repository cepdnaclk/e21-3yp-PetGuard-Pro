import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'health_repository.dart';
import '../models/health_vitals.dart';

class FirebaseHealthRepository implements HealthRepository {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('Firebase health repository initialized');
  }

  @override
  Stream<HealthVitals> getHealthVitalsStream(String petId) {
    return _database.ref('pets/$petId/health').onValue.map((event) {
      if (event.snapshot.value == null) {
        return HealthVitals(
          respiratoryRate: 0,
          temperature: 0.0,
          timestamp: DateTime.now(),
        );
      }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return HealthVitals.fromJson(data);
    });
  }

  // ── Helper: epoch ms range for a given day ─────────────────────────────────
  // Firebase push-ID keys (e.g. -OPxyz123) can't be queried by ISO date string.
  // The firmware now stores timestamp as a plain Unix ms integer, so we query
  // by the child field value using orderByChild('timestamp') + epoch ms range.
  //
  // Requires this index in Firebase database rules:
  //   "health_history": { ".indexOn": ["timestamp"] }

  static int _dayStartMs(DateTime day) =>
      DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;

  static int _dayEndMs(DateTime day) =>
      DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;

  @override
  Future<List<HealthVitals>> getHealthHistoryForDay(
      String petId, DateTime day) async {
    final snapshot = await _database
        .ref('pets/$petId/health_history')
        .orderByChild('timestamp')
        .startAt(_dayStartMs(day).toDouble())
        .endAt(_dayEndMs(day).toDouble())
        .get();

    if (snapshot.value == null) return [];

    final Map<dynamic, dynamic> raw = snapshot.value as Map;
    return raw.values
        .map((e) => HealthVitals.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Stream<List<HealthVitals>> getHealthHistoryStream(
      String petId, DateTime day) {
    return _database
        .ref('pets/$petId/health_history')
        .orderByChild('timestamp')
        .startAt(_dayStartMs(day).toDouble())
        .endAt(_dayEndMs(day).toDouble())
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return <HealthVitals>[];

      final Map<dynamic, dynamic> raw = event.snapshot.value as Map;
      return raw.values
          .map(
              (e) => HealthVitals.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
  }
}
