// lib/features/owner/activity/services/activity_notification_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/services/pet_authorization_module.dart';
import '../models/activity_data.dart';
import '../../location/providers/alerts_provider.dart';

class ActivityNotificationService {
  static final ActivityNotificationService _instance =
      ActivityNotificationService._internal();
  factory ActivityNotificationService() => _instance;
  ActivityNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  StreamSubscription<DatabaseEvent>? _impactSubscription;

  // Tracks the petId currently being listened to.
  // Used to avoid re-subscribing if the same pet is already active.
  String? _currentPetId;

  // WidgetRef is passed in so this service can write to alertsProvider
  // from the background StreamSubscription, outside of Riverpod's widget tree.
  WidgetRef? _ref;

  void setRef(WidgetRef ref) {
    _ref = ref;
  }

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

    await _listenForImpacts();
  }

  // Uses PetAuthorizationModule — single source of truth,
  // same pattern as location/services/cloud_service.dart.
  Future<String> _getPetId() async {
    return await PetAuthorizationModule.instance.getSelectedPetId();
  }

  Future<void> _listenForImpacts() async {
    final petId = await _getPetId();

    // If already listening to this exact pet, do nothing.
    // This prevents duplicate subscriptions on hot reload / repeated calls.
    if (_currentPetId == petId && _impactSubscription != null) {
      debugPrint('ActivityNotificationService: already listening to $petId');
      return;
    }

    // Cancel the old subscription before starting a new one.
    await _impactSubscription?.cancel();
    _impactSubscription = null;
    _currentPetId = petId;

    debugPrint('ActivityNotificationService: subscribing to pet $petId');

    _impactSubscription = FirebaseDatabase.instance
        .ref('pets/$petId/activity/current')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;

      final activity = ActivityData.fromMap(data as Map);

      if (activity.impactDetected) {
        // OS-level notification — unchanged
        _sendImpactNotification(activity);

        // Additional: push to in-app alerts panel if ref is available
        // (i.e. app is in foreground and ref has been set)
        if (_ref != null) {
          final severity = activity.impactSeverity >= 7.0
              ? '🚨 HIGH'
              : activity.impactSeverity >= 4.0
                  ? '⚠️ MEDIUM'
                  : 'ℹ️ LOW';

          _ref!.read(alertsProvider.notifier).add(
                AppAlert(
                  title: 'Impact Detected! $severity',
                  body:
                      'Severity: ${activity.impactSeverity.toStringAsFixed(1)}/10',
                  timestamp: activity.timestamp,
                ),
              );
        }
      }
    });
  }

  // Call this immediately after the user switches accounts/pets.
  // It cancels the old Firebase listener and starts a fresh one
  // pointing at the newly selected pet's data path.
  Future<void> refreshPetListener() async {
    if (!_initialized) return;

    // Reset _currentPetId so _listenForImpacts always re-subscribes
    _currentPetId = null;

    await _listenForImpacts();
    debugPrint('ActivityNotificationService: listener refreshed');
  }

  Future<void> dispose() async {
    await _impactSubscription?.cancel();
    _impactSubscription = null;
    _currentPetId = null;
    _ref = null;
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
