// Entry point screen for authenticated users.
// Owns the BottomNavigationBar and switches between HomeTab and FeaturesTab.
// Also activates ALL three feature monitors here so they stay alive
// regardless of which tab or screen the user is on.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_tab.dart';
import 'features_tab.dart';

// ── Monitor providers — must be watched here so they are always active ────────
import '../location/providers/location_provider.dart';
import '../activity/providers/activity_provider.dart';
import '../health/providers/health_provider.dart';

class UserDashboardScreen extends ConsumerStatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  ConsumerState<UserDashboardScreen> createState() =>
      _UserDashboardScreenState();
}

class _UserDashboardScreenState extends ConsumerState<UserDashboardScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    HomeTab(),
    FeaturesTab(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // ── Activate all three monitors globally ──────────────────────────────
    // These MUST be watched here (not inside individual feature screens)
    // so notifications and in-app alerts fire even when the user hasn't
    // opened the location / activity / health screens.
    //
    // Previously:
    //   • geofenceMonitorProvider was only watched inside dashboard_screen.dart
    //     (location screen) — so it only worked when that screen was open
    //   • activityAlertMonitorProvider was only watched inside
    //     activity_dashboard_screen.dart — same problem
    //   • healthAlertMonitorProvider didn't exist at all
    //
    // Now all three are always active from the moment the user logs in.
    ref.watch(geofenceMonitorProvider);
    ref.watch(locationHistorySaverProvider);
    ref.watch(activityAlertMonitorProvider);
    ref.watch(healthAlertMonitorProvider);

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color.fromARGB(255, 0, 150, 136),
        unselectedItemColor: Colors.grey[600],
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Features',
          ),
        ],
      ),
    );
  }
}
