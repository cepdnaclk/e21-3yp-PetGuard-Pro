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

  Stream<HealthVitals> getHealthVitalsStream() async* {
    final petId = await _getPetId();
    yield* _repository.getHealthVitalsStream(petId);
  }

  Future<List<HealthVitals>> getHealthHistoryForDay(DateTime day) async {
    final petId = await _getPetId();
    return _repository.getHealthHistoryForDay(petId, day);
  }

  Stream<List<HealthVitals>> getHealthHistoryStream(DateTime day) async* {
    final petId = await _getPetId();
    yield* _repository.getHealthHistoryStream(petId, day);
  }

  void setRepository(HealthRepository repository) {
    _repository = repository;
    debugPrint('Health repository switched');
  }
}