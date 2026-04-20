// // lib/features/owner/activity/services/activity_notification_service.dart

// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:firebase_database/firebase_database.dart';
// import '../models/activity_data.dart';

// class ActivityNotificationService {
//   static final ActivityNotificationService _instance =
//       ActivityNotificationService._internal();
//   factory ActivityNotificationService() => _instance;
//   ActivityNotificationService._internal();

//   final FlutterLocalNotificationsPlugin _notifications =
//       FlutterLocalNotificationsPlugin();

//   bool _initialized = false;

//   Future<void> initialize() async {
//     if (_initialized) return;

//     const androidSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     const iosSettings = DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );

//     await _notifications.initialize(
//       const InitializationSettings(
//           android: androidSettings, iOS: iosSettings),
//     );
//     _initialized = true;

//     // Start listening for impacts from Firebase
//     _listenForImpacts();
//   }

//   void _listenForImpacts() {
//     FirebaseDatabase.instance
//         .ref('pets/default_pet/activity/current')
//         .onValue
//         .listen((event) {
//       final data = event.snapshot.value;
//       if (data == null) return;
//       final activity = ActivityData.fromMap(data as Map);
//       if (activity.impactDetected) {
//         _sendImpactNotification(activity);
//       }
//     });
//   }

//   Future<void> _sendImpactNotification(ActivityData activity) async {
//     String severity = activity.impactSeverity >= 7.0
//         ? '🚨 HIGH'
//         : activity.impactSeverity >= 4.0
//             ? '⚠️ MEDIUM'
//             : 'ℹ️ LOW';

//     await _notifications.show(
//       DateTime.now().millisecondsSinceEpoch ~/ 1000,
//       'Impact Detected! $severity',
//       'Severity: ${activity.impactSeverity.toStringAsFixed(1)}/10 at '
//           '${_formatTime(activity.timestamp)}',
//       const NotificationDetails(
//         android: AndroidNotificationDetails(
//           'impact_channel',
//           'Impact Alerts',
//           channelDescription: 'Alerts when your pet experiences an impact',
//           importance: Importance.max,
//           priority: Priority.high,
//           color: Color(0xFFE53935),
//         ),
//         iOS: DarwinNotificationDetails(
//           presentAlert: true,
//           presentBadge: true,
//           presentSound: true,
//         ),
//       ),
//     );
//   }

//   Future<void> sendActivityChangeNotification(String newActivity) async {
//     await _notifications.show(
//       2001,
//       'Activity Update',
//       'Your pet is now $newActivity',
//       const NotificationDetails(
//         android: AndroidNotificationDetails(
//           'activity_channel',
//           'Activity Updates',
//           channelDescription: 'Updates about your pet\'s activity',
//           importance: Importance.defaultImportance,
//           priority: Priority.defaultPriority,
//         ),
//       ),
//     );
//   }

//   String _formatTime(DateTime dt) {
//     return '${dt.hour.toString().padLeft(2, '0')}:'
//         '${dt.minute.toString().padLeft(2, '0')}';
//   }
// }

// lib/features/owner/activity/services/activity_notification_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_data.dart';

class ActivityNotificationService {
  static final ActivityNotificationService _instance =
      ActivityNotificationService._internal();
  factory ActivityNotificationService() => _instance;
  ActivityNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  StreamSubscription<DatabaseEvent>? _impactSubscription;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    _initialized = true;

    // Start listening for impacts from Firebase
    await _listenForImpacts();
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

  Future<void> _listenForImpacts() async {
    final petId = await _getPetId();

    await _impactSubscription?.cancel();

    _impactSubscription = FirebaseDatabase.instance
        .ref('pets/$petId/activity/current')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;

      final activity = ActivityData.fromMap(data as Map);

      if (activity.impactDetected) {
        _sendImpactNotification(activity);
      }
    });
  }

  Future<void> refreshPetListener() async {
    if (!_initialized) return;
    await _listenForImpacts();
  }

  Future<void> dispose() async {
    await _impactSubscription?.cancel();
  }

  Future<void> _sendImpactNotification(ActivityData activity) async {
    String severity = activity.impactSeverity >= 7.0
        ? '🚨 HIGH'
        : activity.impactSeverity >= 4.0
            ? '⚠️ MEDIUM'
            : 'ℹ️ LOW';

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Impact Detected! $severity',
      'Severity: ${activity.impactSeverity.toStringAsFixed(1)}/10 at '
          '${_formatTime(activity.timestamp)}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'impact_channel',
          'Impact Alerts',
          channelDescription: 'Alerts when your pet experiences an impact',
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFFE53935),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> sendActivityChangeNotification(String newActivity) async {
    await _notifications.show(
      2001,
      'Activity Update',
      'Your pet is now $newActivity',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'activity_channel',
          'Activity Updates',
          channelDescription: 'Updates about your pet\'s activity',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}