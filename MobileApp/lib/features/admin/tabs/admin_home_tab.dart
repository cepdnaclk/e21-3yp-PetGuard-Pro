import '../data/admin_repository.dart';
import 'package:flutter/material.dart';
import '../widgets/admin_cards.dart';

class AdminHomeTab extends StatelessWidget {
  AdminHomeTab({super.key});

  final AdminRepository _adminRepository = AdminRepository();

  Future<Map<String, String>> _fetchStats() async {
    return await _adminRepository.fetchStats();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _fetchStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final statsValues = snapshot.data!;
        final stats = [
          {
            "title": "Users",
            "subtitle": "Total Registered",
            "value": statsValues['users']!,
            "icon": Icons.people,
          },
          // {
          //   "title": "Devices",
          //   "subtitle": "Active Devices",
          //   "value": statsValues['devices']!,
          //   "icon": Icons.pets,
          // },
          {
            "title": "Alerts",
            "subtitle": "Pending Alerts",
            "value": statsValues['alerts']!,
            "icon": Icons.warning,
          },
          // {
          //   "title": "Connectivity",
          //   "subtitle": "Average",
          //   "value": statsValues['connectivity']!,
          //   "icon": Icons.wifi,
          // },
        ];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.builder(
            itemCount: stats.length,
            itemBuilder: (context, index) {
              final s = stats[index];
              return GradientCard(
                leading: Icon(s["icon"] as IconData, color: Colors.teal, size: 30),
                title: s["title"] as String,
                subtitle: s["subtitle"] as String,
                trailing: s["value"] as String,
              );
            },
          ),
        );
      },
    );
  }
}