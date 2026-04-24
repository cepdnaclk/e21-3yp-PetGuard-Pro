// import 'package:flutter/foundation.dart';
// import '../repositories/health_repository.dart';
// import '../repositories/firebase_health_repository.dart';
// import '../models/health_vitals.dart';

// class HealthService {
//   // Singleton pattern
//   static final HealthService _instance = HealthService._internal();
//   factory HealthService() => _instance;
//   HealthService._internal();

//   late HealthRepository _repository = FirebaseHealthRepository();
//   final String petId = 'default_pet'; // Change later to support multiple pets

//   Future<void> initialize() async {
//     await _repository.initialize();
//     debugPrint('Health service initialized');
//   }

//   // Get real-time health vitals stream from cloud
//   Stream<HealthVitals> getHealthVitalsStream() {
//     return _repository.getHealthVitalsStream(petId);
//   }

//   // Switch repository (for testing or if you switch to AWS later)
//   void setRepository(HealthRepository repository) {
//     _repository = repository;
//     debugPrint('Health repository switched');
//   }

//   Future<List<HealthVitals>> getHealthHistoryForDay(DateTime day) {
//   return _repository.getHealthHistoryForDay(petId, day);
//   }

// }

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../repositories/health_repository.dart';
import '../repositories/firebase_health_repository.dart';
import '../models/health_vitals.dart';

class HealthService {
  // Singleton
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  late HealthRepository _repository = FirebaseHealthRepository();

  Future<void> initialize() async {
    await _repository.initialize();
    debugPrint('Health service initialized');
  }

  // ─────────────────────────────────────────────
  // Get selected pet id from Firestore
  // fallback = default_pet
  // ─────────────────────────────────────────────
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

  // Real-time health stream
  Stream<HealthVitals> getHealthVitalsStream() async* {
    final petId = await _getPetId();

    yield* _repository.getHealthVitalsStream(petId);
  }

  // Health history
  Future<List<HealthVitals>> getHealthHistoryForDay(DateTime day) async {
    final petId = await _getPetId();

    return _repository.getHealthHistoryForDay(petId, day);
  }

  // Optional repository switch
  void setRepository(HealthRepository repository) {
    _repository = repository;
    debugPrint('Health repository switched');
  }

  Future<List<HealthVitals>> getHealthHistoryForDay(DateTime day) {
  return _repository.getHealthHistoryForDay(petId, day);
  }

  Stream<List<HealthVitals>> getHealthHistoryStream(DateTime day) {
  return _repository.getHealthHistoryStream(petId, day);
}

}