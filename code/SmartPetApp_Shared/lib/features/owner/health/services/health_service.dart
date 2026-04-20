import 'package:flutter/foundation.dart';
import '../repositories/health_repository.dart';
import '../repositories/firebase_health_repository.dart';
import '../models/health_vitals.dart';

class HealthService {
  // Singleton pattern
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  late HealthRepository _repository = FirebaseHealthRepository();
  final String petId = 'default_pet'; // Change later to support multiple pets

  Future<void> initialize() async {
    await _repository.initialize();
    debugPrint('Health service initialized');
  }

  // Get real-time health vitals stream from cloud
  Stream<HealthVitals> getHealthVitalsStream() {
    return _repository.getHealthVitalsStream(petId);
  }

  // Switch repository (for testing or if you switch to AWS later)
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