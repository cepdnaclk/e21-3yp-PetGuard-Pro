// lib/features/owner/activity/providers/activity_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/services/pet_authorization_module.dart';
import '../models/activity_data.dart';
import '../repositories/firebase_activity_repository.dart';
import '../../location/providers/alerts_provider.dart';

// ─────────────────────────────────────────────────────────────
// Get current user's selectedPetId via PetAuthorizationModule
// (same pattern as location/services/cloud_service.dart)
// ─────────────────────────────────────────────────────────────
final selectedPetIdProvider = FutureProvider<String>((ref) async {
  return await PetAuthorizationModule.instance.getSelectedPetId();
});

// ─────────────────────────────────────────────────────────────
// Repository — waits for the real petId before being created.
// Using FutureProvider ensures we NEVER fall back to 'default_pet'
// during the async loading window when switching accounts.
// ─────────────────────────────────────────────────────────────
final _activityRepoProvider =
    FutureProvider<FirebaseActivityRepository>((ref) async {
  // Awaits the resolved petId — never proceeds with a fallback
  final petId = await ref.watch(selectedPetIdProvider.future);
  return FirebaseActivityRepository(petId: petId);
});

// ─────────────────────────────────────────────────────────────
// Streams — all await the repo before subscribing,
// so they always use the correct account's data path.
// ─────────────────────────────────────────────────────────────
final currentActivityProvider = StreamProvider<ActivityData?>((ref) async* {
  final repo = await ref.watch(_activityRepoProvider.future);
  yield* repo.getCurrentActivityStream();
});

final activityHistoryProvider =
    StreamProvider<List<ActivityData>>((ref) async* {
  final repo = await ref.watch(_activityRepoProvider.future);
  yield* repo.getActivityHistoryStream(limit: 50);
});

final dailySummariesProvider =
    StreamProvider<List<ActivitySummary>>((ref) async* {
  final repo = await ref.watch(_activityRepoProvider.future);
  yield* repo.getDailySummariesStream(days: 7);
});

final impactAlertsProvider = StreamProvider<List<ActivityData>>((ref) async* {
  final repo = await ref.watch(_activityRepoProvider.future);
  yield* repo.getImpactAlertsStream(limit: 20);
});

// ─────────────────────────────────────────────────────────────
// Monitor live activity and push impacts to in-app alerts panel.
// OS-level notifications are handled separately by
// ActivityNotificationService — this is an additional layer only.
// ─────────────────────────────────────────────────────────────
final activityAlertMonitorProvider = Provider<void>((ref) {
  final currentAsync = ref.watch(currentActivityProvider);

  currentAsync.whenData((activity) {
    if (activity == null) return;
    if (!activity.impactDetected) return;

    final severity = activity.impactSeverity >= 7.0
        ? '🚨 HIGH'
        : activity.impactSeverity >= 4.0
            ? '⚠️ MEDIUM'
            : 'ℹ️ LOW';

    ref.read(alertsProvider.notifier).add(
          AppAlert(
            title: 'Impact Detected! $severity',
            body: 'Severity: ${activity.impactSeverity.toStringAsFixed(1)}/10',
            timestamp: activity.timestamp,
          ),
        );
  });
});
