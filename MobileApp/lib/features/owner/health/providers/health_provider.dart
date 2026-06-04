// lib/features/owner/health/providers/health_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/health_service.dart';
import '../models/health_vitals.dart';
import '../models/dog_profile.dart';
import '../models/vital_thresholds.dart';
import '../../location/providers/alerts_provider.dart';
import '../../location/services/notification_service.dart';

// ── Health service ────────────────────────────────────────────────────────────

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

// ── Live vitals stream ────────────────────────────────────────────────────────

final healthVitalsStreamProvider = StreamProvider<HealthVitals>((ref) {
  final healthService = ref.watch(healthServiceProvider);
  return healthService.getHealthVitalsStream();
});

// ── History ───────────────────────────────────────────────────────────────────

final selectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

final healthHistoryProvider =
    StreamProvider.autoDispose<List<HealthVitals>>((ref) {
  final service = ref.watch(healthServiceProvider);
  final day = ref.watch(selectedDayProvider);
  return service.getHealthHistoryStream(day);
});

// ── Dog profile ───────────────────────────────────────────────────────────────

final dogProfileProvider = StreamProvider<DogProfile>((ref) async* {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    yield DogProfile.defaults;
    return;
  }

  final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

  final petId = (userDoc.data()?['selectedPetId'] as String?) ?? '';
  if (petId.isEmpty) {
    yield DogProfile.defaults;
    return;
  }

  yield* FirebaseFirestore.instance
      .collection('pets')
      .doc(petId)
      .snapshots()
      .map((snap) {
    if (!snap.exists || snap.data() == null) return DogProfile.defaults;
    return DogProfile.fromFirestore(snap.data()!);
  });
});

// ── Thresholds ────────────────────────────────────────────────────────────────

final vitalThresholdsProvider = Provider<VitalThresholds>((ref) {
  final profileAsync = ref.watch(dogProfileProvider);
  final profile = profileAsync.valueOrNull ?? DogProfile.defaults;
  return VitalThresholds.fromProfile(profile);
});

// ── Health monitor — fires OS notifications AND in-app alerts ─────────────────
// This is the equivalent of geofenceMonitorProvider for the health feature.
// It must be ref.watch()ed in UserDashboardScreen so it stays alive
// regardless of which tab or screen the user is on.
// Previously this didn't exist — health had NO notification system at all.

final healthAlertMonitorProvider = Provider<void>((ref) {
  final vitalsAsync = ref.watch(healthVitalsStreamProvider);
  final thresholds = ref.watch(vitalThresholdsProvider);
  final notificationService = NotificationService();

  vitalsAsync.whenData((vitals) {
    // ── Respiratory rate alerts ───────────────────────────────────────────
    if (vitals.respiratoryRate > 0) {
      final respStatus = thresholds.respiratoryStatus(vitals.respiratoryRate);

      if (respStatus == VitalStatus.danger) {
        // OS notification
        notificationService.showNotification(
          title: '🚨 Respiratory Rate Critical!',
          body:
              'Rate: ${vitals.respiratoryRate} breaths/min — immediate attention needed.',
        );
        // In-app alert
        ref.read(alertsProvider.notifier).add(AppAlert(
              title: '🚨 Respiratory Rate Critical!',
              body:
                  'Rate: ${vitals.respiratoryRate} breaths/min — outside safe range.',
              timestamp: vitals.timestamp,
            ));
      } else if (respStatus == VitalStatus.caution) {
        notificationService.showNotification(
          title: '⚠️ Respiratory Rate Elevated',
          body:
              'Rate: ${vitals.respiratoryRate} breaths/min — monitor closely.',
        );
        ref.read(alertsProvider.notifier).add(AppAlert(
              title: '⚠️ Respiratory Rate Elevated',
              body:
                  'Rate: ${vitals.respiratoryRate} breaths/min — monitor closely.',
              timestamp: vitals.timestamp,
            ));
      }
    }

    // ── Temperature alerts ────────────────────────────────────────────────
    if (vitals.temperature > 0) {
      final tempStatus =
          thresholds.temperatureStatus(vitals.calibratedTemperature);

      if (tempStatus == VitalStatus.danger) {
        notificationService.showNotification(
          title: '🚨 Temperature Critical!',
          body:
              'Temp: ${vitals.calibratedTemperature.toStringAsFixed(1)}°C — immediate attention needed.',
        );
        ref.read(alertsProvider.notifier).add(AppAlert(
              title: '🚨 Temperature Critical!',
              body:
                  'Temp: ${vitals.calibratedTemperature.toStringAsFixed(1)}°C — outside safe range.',
              timestamp: vitals.timestamp,
            ));
      } else if (tempStatus == VitalStatus.caution) {
        notificationService.showNotification(
          title: '⚠️ Temperature Elevated',
          body:
              'Temp: ${vitals.calibratedTemperature.toStringAsFixed(1)}°C — monitor closely.',
        );
        ref.read(alertsProvider.notifier).add(AppAlert(
              title: '⚠️ Temperature Elevated',
              body:
                  'Temp: ${vitals.calibratedTemperature.toStringAsFixed(1)}°C — monitor closely.',
              timestamp: vitals.timestamp,
            ));
      }
    }
  });
});
