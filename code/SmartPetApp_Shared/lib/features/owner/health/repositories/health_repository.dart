import '../models/health_vitals.dart';

/// Abstract interface for health data operations
abstract class HealthRepository {
  Future<void> initialize();
  
  /// Stream of real-time health vitals from cloud
  Stream<HealthVitals> getHealthVitalsStream(String petId);
  Future<List<HealthVitals>> getHealthHistoryForDay(String petId, DateTime day);
  Stream<List<HealthVitals>> getHealthHistoryStream(String petId, DateTime day);
}
