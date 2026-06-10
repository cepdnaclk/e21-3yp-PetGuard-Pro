// lib/features/owner/activity/providers/activity_provider.dart
/*
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
  // Watch current activity to trigger updates
  ref.watch(currentActivityProvider); // Add this line
  yield* repo.getDailySummariesStream(days: 7);
});

final impactAlertsProvider = StreamProvider<List<ActivityData>>((ref) async* {
  final repo = await ref.watch(_activityRepoProvider.future);
  yield* repo.getImpactAlertsStream(limit: 20);
});

// ─────────────────────────────────────────────────────────────
// Computed today's summary from activity history (real-time aggregation)
// This calculates total steps, active minutes, and impacts from today's
// activity data, ensuring it updates whenever new activity arrives.
// ─────────────────────────────────────────────────────────────
final todaysSummaryProvider = Provider<ActivitySummary?>((ref) {
  final historyAsync = ref.watch(activityHistoryProvider);
  
  return historyAsync.when(
    data: (activities) {
      if (activities.isEmpty) return null;
      
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      
      // Filter activities from today
      final todayActivities = activities.where((activity) {
        return activity.timestamp.isAfter(todayStart) &&
            activity.timestamp.isBefore(now);
      }).toList();
      
      if (todayActivities.isEmpty) return null;
      
      // Sum up totals for today
      int totalSteps = 0;
      double totalActiveMinutes = 0.0;
      int impactCount = 0;
      
      for (var activity in todayActivities) {
        totalSteps += activity.stepCount;
        totalActiveMinutes += activity.activeMinutes;
        if (activity.impactDetected) impactCount++;
      }
      
      return ActivitySummary(
        date: todayStart,
        totalSteps: totalSteps,
        totalActiveMinutes: totalActiveMinutes,
        impactCount: impactCount,
        peakIntensityTime: _getPeakIntensityTime(todayActivities),
      );
    },
    loading: () => null,
    error: (e, _) => null,
  );
});

// ─────────────────────────────────────────────────────────────
// Helper: find peak intensity time from today's activities
// ─────────────────────────────────────────────────────────────
String _getPeakIntensityTime(List<ActivityData> activities) {
  if (activities.isEmpty) return '--:--';
  
  final peakActivity = activities.reduce((a, b) {
    final aMag = a.accelerationMagnitude;
    final bMag = b.accelerationMagnitude;
    return aMag > bMag ? a : b;
  });
  
  final time = peakActivity.timestamp;
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

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
*/

// lib/features/owner/activity/providers/activity_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/services/pet_authorization_module.dart';
import '../models/activity_data.dart';
import '../repositories/firebase_activity_repository.dart';
import '../../location/providers/alerts_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Get current user's selectedPetId via PetAuthorizationModule
// ─────────────────────────────────────────────────────────────────────────────
final selectedPetIdProvider = FutureProvider<String>((ref) async {
  return await PetAuthorizationModule.instance.getSelectedPetId();
});

// ─────────────────────────────────────────────────────────────────────────────
// Repository — waits for the real petId before being created.
// ─────────────────────────────────────────────────────────────────────────────
final _activityRepoProvider =
    FutureProvider<FirebaseActivityRepository>((ref) async {
  final petId = await ref.watch(selectedPetIdProvider.future);
  return FirebaseActivityRepository(petId: petId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Streams
// ─────────────────────────────────────────────────────────────────────────────
final currentActivityProvider = StreamProvider<ActivityData?>((ref) async* {
  final repo = await ref.watch(_activityRepoProvider.future);
  yield* repo.getCurrentActivityStream();
});

final activityHistoryProvider =
    StreamProvider<List<ActivityData>>((ref) async* {
  final repo = await ref.watch(_activityRepoProvider.future);
  // limit: 500 ensures a full day of entries is always covered
  yield* repo.getActivityHistoryStream(limit: 500);
});

final dailySummariesProvider =
    StreamProvider<List<ActivitySummary>>((ref) async* {
  final repo = await ref.watch(_activityRepoProvider.future);
  ref.watch(currentActivityProvider);
  yield* repo.getDailySummariesStream(days: 7);
});

final impactAlertsProvider = StreamProvider<List<ActivityData>>((ref) async* {
  final repo = await ref.watch(_activityRepoProvider.future);
  yield* repo.getImpactAlertsStream(limit: 20);
});

// ─────────────────────────────────────────────────────────────────────────────
// todayAsSummaryListProvider
//
// Aggregates ALL history entries from midnight → now into a single
// ActivitySummary and returns it as a List so the existing Summary tab
// chart/stat widgets work without any changes.
//
// This is the provider the Summary tab should watch instead of
// dailySummariesProvider, because the Firebase DB only has
// pets/$petId/activity/current  and  pets/$petId/activity/history —
// there is no daily_summary node. dailySummariesProvider would always
// return an empty list, causing all stats to show 0.
// ─────────────────────────────────────────────────────────────────────────────
final todayAsSummaryListProvider =
    Provider<AsyncValue<List<ActivitySummary>>>((ref) {
  final historyAsync = ref.watch(activityHistoryProvider);

  return historyAsync.when(
    data: (activities) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // Keep only entries from midnight up to right now
      final todayActivities = activities
          .where((a) =>
              a.timestamp.isAfter(todayStart) && a.timestamp.isBefore(now))
          .toList();

      if (todayActivities.isEmpty) return const AsyncData([]);

      // Aggregate totals
      int totalSteps = 0;
      double totalActiveMinutes = 0.0;
      int impactCount = 0;

      for (final a in todayActivities) {
        totalSteps += a.stepCount;
        totalActiveMinutes += a.activeMinutes;
        if (a.impactDetected) impactCount++;
      }

      final summary = ActivitySummary(
        date: todayStart,
        totalSteps: totalSteps,
        totalActiveMinutes: totalActiveMinutes,
        impactCount: impactCount,
        activityBreakdown: const {},
        peakIntensityTime: _getPeakIntensityTime(todayActivities),
      );

      return AsyncData([summary]);
    },
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// todaysSummaryProvider
// Returns today's summary as a single nullable object (used elsewhere if needed)
// ─────────────────────────────────────────────────────────────────────────────
final todaysSummaryProvider = Provider<ActivitySummary?>((ref) {
  final summaryAsync = ref.watch(todayAsSummaryListProvider);
  return summaryAsync.whenOrNull(data: (list) => list.isEmpty ? null : list.first);
});

// ─────────────────────────────────────────────────────────────────────────────
// Helper: find the time of peak movement magnitude today
// ─────────────────────────────────────────────────────────────────────────────
String _getPeakIntensityTime(List<ActivityData> activities) {
  if (activities.isEmpty) return '--:--';

  final peakActivity = activities.reduce((a, b) {
    return a.magnitude > b.magnitude ? a : b;
  });

  final time = peakActivity.timestamp;
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Monitor live activity and push impacts to in-app alerts panel.
// ─────────────────────────────────────────────────────────────────────────────
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