import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/admin_cards.dart';
import '../dialogs/add_alert_dialog.dart';
import '../dialogs/edit_alert_dialog.dart';

class AlertsTab extends StatelessWidget {
  const AlertsTab({super.key});

  void _deleteAlert(DocumentSnapshot alert, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Alert'),
        content: Text('Are you sure you want to delete "${alert['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              alert.reference.delete().then((_) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alert deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }).catchError((error) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting alert: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('alerts').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final alerts = snapshot.data!.docs;

          if (alerts.isEmpty) {
            return const Center(child: Text('No alerts found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final a = alerts[index];
              final isPending = a['status'] == 'Pending';

              return DashboardCard(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: (a['type'] == 'Maintenance'
                          ? Colors.orange
                          : Colors.blue)
                      .withOpacity(0.1),
                  child: Icon(
                    a['type'] == 'Maintenance' ? Icons.build : Icons.campaign,
                    color: a['type'] == 'Maintenance'
                        ? Colors.orange
                        : Colors.blue,
                  ),
                ),
                title: a['title'] ?? 'No Title',
                subtitle: a['description'] ?? '',
                badge1: a['type'] ?? 'System',
                badge1Color: a['type'] == 'Maintenance' ? Colors.orange : Colors.blue,
                badge2: a['status'] ?? 'Pending',
                badge2Color: isPending ? Colors.orange : Colors.green,
                onEdit: () => showDialog(
                  context: context,
                  builder: (context) => EditAlertDialog(alert: a),
                ),
                onDelete: () => _deleteAlert(a, context),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const AddAlertDialog(),
        ),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}