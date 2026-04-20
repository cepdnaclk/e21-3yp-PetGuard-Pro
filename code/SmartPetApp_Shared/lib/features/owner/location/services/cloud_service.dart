// import 'package:flutter/foundation.dart';
// import '../repositories/cloud_repository.dart';
// import '../repositories/firebase_repository.dart';
// import '../models/pet_location.dart';
// import '../models/geofence.dart';
// import '../models/location_history_entry.dart';

// class CloudService {
//   static final CloudService _instance = CloudService._internal();
//   factory CloudService() => _instance;
//   CloudService._internal();

//   late CloudRepository _repository = FirebaseRepository();
//   final String petId = 'default_pet';

//   Future<void> initialize() async {
//     await _repository.initialize();
//     debugPrint('Cloud service initialized');
//   }

//   Stream<PetLocation> getLocationStream() {
//     return _repository.getLocationStream(petId);
//   }

//   Future<void> uploadLocation(PetLocation location) async {
//     await _repository.uploadLocation(petId, location);
//   }

//   Future<void> saveGeofence(Geofence geofence) async {
//     await _repository.saveGeofence(petId, geofence);
//   }

//   Future<void> deleteGeofence(String geofenceId) async {
//     await _repository.deleteGeofence(petId, geofenceId);
//   }

//   Future<List<Geofence>> getGeofences() async {
//     return await _repository.getGeofences(petId);
//   }

//   Stream<List<Geofence>> getGeofencesStream() {
//     return _repository.getGeofencesStream(petId);
//   }

//   Future<void> uploadHistory(List history) async {
//     await _repository.uploadLocationHistory(petId, history);
//   }

//   Future<void> logEvent(String eventType, Map<String, dynamic> data) async {
//     await _repository.logEvent(petId, eventType, data);
//   }

//   // NEW: Get full history from Firebase
//   Future<List<Map<String, dynamic>>> getLocationHistory() async {
//     return await _repository.getLocationHistory(petId);
//   }

//   // NEW: Save single history entry to Firebase
//   Future<void> saveHistoryEntry(LocationHistoryEntry entry) async {
//     await _repository.saveHistoryEntry(petId, entry.toJson());
//   }

//   void setRepository(CloudRepository repository) {
//     _repository = repository;
//     debugPrint('Cloud repository switched');
//   }
// }

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../repositories/cloud_repository.dart';
import '../repositories/firebase_repository.dart';
import '../models/pet_location.dart';
import '../models/geofence.dart';
import '../models/location_history_entry.dart';

class CloudService {
  static final CloudService _instance = CloudService._internal();
  factory CloudService() => _instance;
  CloudService._internal();

  late CloudRepository _repository = FirebaseRepository();

  Future<void> initialize() async {
    await _repository.initialize();
    debugPrint('Cloud service initialized');
  }

  Future<String> _getPetId() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return 'default_pet';

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return 'default_pet';

    final data = doc.data();
    if (data == null) return 'default_pet';

    return data['selectedPetId'] ?? 'default_pet';
  }

  Stream<PetLocation> getLocationStream() async* {
    final petId = await _getPetId();
    yield* _repository.getLocationStream(petId);
  }

  Future<void> uploadLocation(PetLocation location) async {
    final petId = await _getPetId();
    await _repository.uploadLocation(petId, location);
  }

  Future<void> saveGeofence(Geofence geofence) async {
    final petId = await _getPetId();
    await _repository.saveGeofence(petId, geofence);
  }

  Future<void> deleteGeofence(String geofenceId) async {
    final petId = await _getPetId();
    await _repository.deleteGeofence(petId, geofenceId);
  }

  Future<List<Geofence>> getGeofences() async {
    final petId = await _getPetId();
    return await _repository.getGeofences(petId);
  }

  Stream<List<Geofence>> getGeofencesStream() async* {
    final petId = await _getPetId();
    yield* _repository.getGeofencesStream(petId);
  }

  Future<void> uploadHistory(List history) async {
    final petId = await _getPetId();
    await _repository.uploadLocationHistory(petId, history);
  }

  Future<void> logEvent(String eventType, Map<String, dynamic> data) async {
    final petId = await _getPetId();
    await _repository.logEvent(petId, eventType, data);
  }

  Future<List<Map<String, dynamic>>> getLocationHistory() async {
    final petId = await _getPetId();
    return await _repository.getLocationHistory(petId);
  }

  Future<void> saveHistoryEntry(LocationHistoryEntry entry) async {
    final petId = await _getPetId();
    await _repository.saveHistoryEntry(petId, entry.toJson());
  }

  void setRepository(CloudRepository repository) {
    _repository = repository;
    debugPrint('Cloud repository switched');
  }
}