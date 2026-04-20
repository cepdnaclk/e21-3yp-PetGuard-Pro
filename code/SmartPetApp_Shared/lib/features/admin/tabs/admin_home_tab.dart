import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/admin_cards.dart';

class AdminHomeTab extends StatelessWidget {
  const AdminHomeTab({super.key});

  Future<Map<String, String>> _fetchStats() async {
    final usersSnap = await FirebaseFirestore.instance.collection('users').get();
    final devicesSnap = await FirebaseFirestore.instance.collection('devices').get();
    final alertsSnap = await FirebaseFirestore.instance
        .collection('alerts')
        .where('status', isEqualTo: 'Pending')
        .get();

    final devices = devicesSnap.docs;
    double totalConnectivity = 0;
    for (var d in devices) {
      totalConnectivity += (d['connectivity'] ?? 0);
    }

    final connectivity =
        devices.isNotEmpty ? "${(totalConnectivity / devices.length).round()}%" : "0%";

    return {
      'users': usersSnap.size.toString(),
      'devices': devicesSnap.size.toString(),
      'alerts': alertsSnap.size.toString(),
      'connectivity': connectivity,
    };
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
          {
            "title": "Devices",
            "subtitle": "Active Devices",
            "value": statsValues['devices']!,
            "icon": Icons.pets,
          },
          {
            "title": "Alerts",
            "subtitle": "Pending Alerts",
            "value": statsValues['alerts']!,
            "icon": Icons.warning,
          },
          {
            "title": "Connectivity",
            "subtitle": "Average",
            "value": statsValues['connectivity']!,
            "icon": Icons.wifi,
          },
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