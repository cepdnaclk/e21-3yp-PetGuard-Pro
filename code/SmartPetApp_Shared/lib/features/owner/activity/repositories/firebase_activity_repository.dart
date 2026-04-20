// // lib/features/owner/activity/repositories/firebase_activity_repository.dart

// import 'package:firebase_database/firebase_database.dart';
// import '../models/activity_data.dart';

// class FirebaseActivityRepository {
//   final DatabaseReference _db = FirebaseDatabase.instance.ref();
//   static const String _petId = 'default_pet';

//   // ─── Live current activity stream ───────────────────────────────────────────
//   Stream<ActivityData?> getCurrentActivityStream() {
//     return _db
//         .child('pets/$_petId/activity/current')
//         .onValue
//         .map((event) {
//       final data = event.snapshot.value;
//       if (data == null) return null;
//       return ActivityData.fromMap(data as Map);
//     });
//   }

//   // ─── History: last N entries ─────────────────────────────────────────────────
//   Stream<List<ActivityData>> getActivityHistoryStream({int limit = 50}) {
//     return _db
//         .child('pets/$_petId/activity/history')
//         .orderByChild('timestamp')
//         .limitToLast(limit)
//         .onValue
//         .map((event) {
//       final data = event.snapshot.value;
//       if (data == null) return [];
//       final map = data as Map;
//       final list = map.values
//           .map((v) => ActivityData.fromMap(v as Map))
//           .toList();
//       list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
//       return list;
//     });
//   }

//   // ─── Daily summaries (last 7 days) ──────────────────────────────────────────
//   Stream<List<ActivitySummary>> getDailySummariesStream({int days = 7}) {
//     return _db
//         .child('pets/$_petId/activity/daily_summary')
//         .orderByChild('date')
//         .limitToLast(days)
//         .onValue
//         .map((event) {
//       final data = event.snapshot.value;
//       if (data == null) return [];
//       final map = data as Map;
//       final list = map.values
//           .map((v) => ActivitySummary.fromMap(v as Map))
//           .toList();
//       list.sort((a, b) => b.date.compareTo(a.date));
//       return list;
//     });
//   }

//   // ─── Impact alerts stream ────────────────────────────────────────────────────
//   Stream<List<ActivityData>> getImpactAlertsStream({int limit = 20}) {
//     return _db
//         .child('pets/$_petId/activity/history')
//         .orderByChild('impact_detected')
//         .equalTo(true)
//         .limitToLast(limit)
//         .onValue
//         .map((event) {
//       final data = event.snapshot.value;
//       if (data == null) return [];
//       final map = data as Map;
//       final list = map.values
//           .map((v) => ActivityData.fromMap(v as Map))
//           .toList();
//       list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
//       return list;
//     });
//   }
// }

// lib/features/owner/activity/repositories/firebase_activity_repository.dart

import 'package:firebase_database/firebase_database.dart';
import '../models/activity_data.dart';

class FirebaseActivityRepository {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final String petId;

  FirebaseActivityRepository({required this.petId});

  // ─── Live current activity stream ───────────────────────────────────────────
  Stream<ActivityData?> getCurrentActivityStream() {
    return _db.child('pets/$petId/activity/current').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return ActivityData.fromMap(data as Map);
    });
  }

  // ─── History: last N entries ────────────────────────────────────────────────
  Stream<List<ActivityData>> getActivityHistoryStream({int limit = 50}) {
    return _db
        .child('pets/$petId/activity/history')
        .orderByChild('timestamp')
        .limitToLast(limit)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      final map = data as Map;
      final list = map.values.map((v) => ActivityData.fromMap(v as Map)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  // ─── Daily summaries (last N days) ──────────────────────────────────────────
  Stream<List<ActivitySummary>> getDailySummariesStream({int days = 7}) {
    return _db
        .child('pets/$petId/activity/daily_summary')
        .orderByChild('date')
        .limitToLast(days)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      final map = data as Map;
      final list =
          map.values.map((v) => ActivitySummary.fromMap(v as Map)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  // ─── Impact alerts stream ───────────────────────────────────────────────────
  Stream<List<ActivityData>> getImpactAlertsStream({int limit = 20}) {
    return _db
        .child('pets/$petId/activity/history')
        .orderByChild('impact_detected')
        .equalTo(true)
        .limitToLast(limit)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      final map = data as Map;
      final list = map.values.map((v) => ActivityData.fromMap(v as Map)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }
}