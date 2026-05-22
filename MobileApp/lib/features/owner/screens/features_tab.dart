// FeaturesTab – lists the three main real-time features of PetGuard Pro.
// Each card navigates to its respective dashboard screen.
// Contains NO Firebase logic.

import 'package:flutter/material.dart';
import '../location/screens/dashboard_screen.dart' show LocationDashboard;
import '../health/screens/health_dashboard_screen.dart';
import '../activity/screens/activity_dashboard_screen.dart';
import 'dashboard_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Feature definition model
// ─────────────────────────────────────────────────────────────────────────────

/// Describes one feature card: icon, labels, and destination widget builder.
class _Feature {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final WidgetBuilder destination;

  const _Feature({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.destination,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// FeaturesTab
// ─────────────────────────────────────────────────────────────────────────────

class FeaturesTab extends StatelessWidget {
  const FeaturesTab({super.key});

  static final List<_Feature> _features = [
    _Feature(
      title: 'Location Monitoring',
      subtitle: 'Pet Location Details',
      value: 'Active',
      icon: Icons.gps_fixed,
      destination: (_) => const LocationDashboard(),
    ),
    _Feature(
      title: 'Health Monitoring',
      subtitle: 'Pet Health Stats',
      value: '92%',
      icon: Icons.favorite,
      destination: (_) => const HealthDashboardScreen(),
    ),
    _Feature(
      title: 'Activity Monitoring',
      subtitle: 'Daily Pet Activity',
      value: 'Normal',
      icon: Icons.directions_run,
      destination: (_) => const ActivityDashboardScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const DashboardAppBar(title: 'RealTime Features'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: _features.length,
          itemBuilder: (context, index) {
            final feature = _features[index];
            return _FeatureCard(feature: feature);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widget
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps a [GradientCard] in an [InkWell] that navigates to the feature's
/// destination screen when tapped.
class _FeatureCard extends StatelessWidget {
  final _Feature feature;

  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: feature.destination),
        );
      },
      child: GradientCard(
        leading: Icon(
          feature.icon,
          color: const Color.fromARGB(255, 0, 150, 136),
          size: 30,
        ),
        title: feature.title,
        subtitle: feature.subtitle,
        trailing: feature.value,
        colors: [Colors.blueGrey.shade50, Colors.blueGrey.shade100],
      ),
    );
  }
}
