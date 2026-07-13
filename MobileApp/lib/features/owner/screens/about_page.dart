import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF009688);

    return Scaffold(
      appBar: AppBar(
        title: const Text('About PetGuard Pro'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // App Branding Icon
            Center(
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.pets_rounded,
                      size: 48,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'PetGuard Pro',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Version 1.2.0',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Description Block
            Text(
              'PetGuard Pro is an advanced real-time pet tracking and health monitoring solution. By combining lightweight smart collar sensors with real-time cloud data streams, the system monitors location telemetry, logs physical activity, configures custom geofence safe zones, and analyzes vital thresholds to keep your pets safe and healthy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Feature Details List
            _buildSectionHeader(context, 'Key Features'),
            const SizedBox(height: 12),
            _buildFeatureRow(
              icon: Icons.gps_fixed_rounded,
              title: 'Real-time GPS Tracking',
              desc: 'Live location synchronization with circular and polygonal geofence boundaries.',
            ),
            _buildFeatureRow(
              icon: Icons.favorite_rounded,
              title: 'Health Vitals Analysis',
              desc: 'High-frequency logging of heart rate (BPM) and body temperature parameters.',
            ),
            _buildFeatureRow(
              icon: Icons.directions_run_rounded,
              title: 'Activity Level Summary',
              desc: 'Detailed motion classifications and daily steps tracker logs.',
            ),
            _buildFeatureRow(
              icon: Icons.warning_amber_rounded,
              title: 'G-Sensor Alert Trigger',
              desc: 'Instant warnings for high acceleration fall/impact detections.',
            ),

            const SizedBox(height: 24),

            // Hardware Specs Section
            _buildSectionHeader(context, 'System specifications'),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? Colors.white10 : Colors.blueGrey.shade50,
                ),
              ),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  children: [
                    _buildSpecRow('Collar Firmware', 'v2.4.1'),
                    const Divider(height: 16),
                    _buildSpecRow('Supported Protocol', 'Wi-Fi 802.11 b/g/n / BLE 5.0'),
                    const Divider(height: 16),
                    _buildSpecRow('Cloud Gateway', 'Firebase Realtime Database & Firestore'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Copyright Section
            Text(
              'Made with ❤️ by the PetGuard Pro Team',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Copyright © 2026 PetGuard Pro. All rights reserved.',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF009688).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF009688),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.blueGrey,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            val,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
