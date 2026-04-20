// // lib/features/owner/activity/providers/activity_provider.dart

// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../models/activity_data.dart';
// import '../repositories/firebase_activity_repository.dart';

// // ✅ Repo created inside provider — guaranteed Firebase is ready
// final _activityRepoProvider = Provider<FirebaseActivityRepository>((ref) {
//   return FirebaseActivityRepository();
// });

// final currentActivityProvider = StreamProvider<ActivityData?>((ref) {
//   return ref.watch(_activityRepoProvider).getCurrentActivityStream();
// });

// final activityHistoryProvider = StreamProvider<List<ActivityData>>((ref) {
//   return ref.watch(_activityRepoProvider).getActivityHistoryStream(limit: 50);
// });

// final dailySummariesProvider = StreamProvider<List<ActivitySummary>>((ref) {
//   return ref.watch(_activityRepoProvider).getDailySummariesStream(days: 7);
// });

// final impactAlertsProvider = StreamProvider<List<ActivityData>>((ref) {
//   return ref.watch(_activityRepoProvider).getImpactAlertsStream(limit: 20);
// });

// lib/features/owner/activity/providers/activity_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity_data.dart';
import '../repositories/firebase_activity_repository.dart';

// ─────────────────────────────────────────────────────────────
// Get current user's selectedPetId from Firestore
// fallback = default_pet
// ─────────────────────────────────────────────────────────────
final selectedPetIdProvider = FutureProvider<String>((ref) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return 'default_pet';
  }

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  if (!doc.exists) {
    return 'default_pet';
  }

  final data = doc.data();

  if (data == null) {
    return 'default_pet';
  }

  return data['selectedPetId'] ?? 'default_pet';
});

// ─────────────────────────────────────────────────────────────
// Repository with dynamic petId
// ─────────────────────────────────────────────────────────────
final _activityRepoProvider =
    Provider<FirebaseActivityRepository>((ref) {
  final petIdAsync = ref.watch(selectedPetIdProvider);

  final petId = petIdAsync.maybeWhen(
    data: (value) => value,
    orElse: () => 'default_pet',
  );

  return FirebaseActivityRepository(petId: petId);
});

// ─────────────────────────────────────────────────────────────
// Streams
// ─────────────────────────────────────────────────────────────
final currentActivityProvider = StreamProvider<ActivityData?>((ref) {
  return ref.watch(_activityRepoProvider).getCurrentActivityStream();
});

final activityHistoryProvider = StreamProvider<List<ActivityData>>((ref) {
  return ref.watch(_activityRepoProvider).getActivityHistoryStream(limit: 50);
});

final dailySummariesProvider =
    StreamProvider<List<ActivitySummary>>((ref) {
  return ref.watch(_activityRepoProvider).getDailySummariesStream(days: 7);
});

final impactAlertsProvider = StreamProvider<List<ActivityData>>((ref) {
  return ref.watch(_activityRepoProvider).getImpactAlertsStream(limit: 20);
});