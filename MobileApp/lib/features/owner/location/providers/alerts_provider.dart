// lib/features/owner/location/providers/alerts_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────
// Model for a single in-app alert
// Used by both the location (geofence breach) and
// activity (impact detected) features
// ─────────────────────────────────────────────────────────────
class AppAlert {
  final String title;
  final String body;
  final DateTime timestamp;

  AppAlert({
    required this.title,
    required this.body,
    required this.timestamp,
  });
}

// ─────────────────────────────────────────────────────────────
// Notifier — holds the list of in-app alerts in memory
// Newest alert is always first in the list
// ─────────────────────────────────────────────────────────────
class AlertsNotifier extends StateNotifier<List<AppAlert>> {
  AlertsNotifier() : super([]);

  void add(AppAlert alert) {
    state = [alert, ...state];
  }

  void clearAll() {
    state = [];
  }
}

// ─────────────────────────────────────────────────────────────
// Provider — single instance shared across the whole app
// Both location and activity features write to this
// DashboardAppBar reads from this to show the Alerts panel
// ─────────────────────────────────────────────────────────────
final alertsProvider =
    StateNotifierProvider<AlertsNotifier, List<AppAlert>>((ref) {
  return AlertsNotifier();
});
