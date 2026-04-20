import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/health_service.dart';
import '../models/health_vitals.dart';

// Provider for HealthService instance
final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

// Provider for continuous health vitals tracking stream
final healthVitalsStreamProvider = StreamProvider<HealthVitals>((ref) {
  final healthService = ref.watch(healthServiceProvider);
  return healthService.getHealthVitalsStream();
});

final selectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

final healthHistoryProvider = StreamProvider.autoDispose<List<HealthVitals>>((ref) {
  final service = ref.watch(healthServiceProvider);
  final day = ref.watch(selectedDayProvider);
  return service.getHealthHistoryStream(day);
});